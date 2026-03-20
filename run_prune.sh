#!/bin/bash
# ~/pruner4n8n/run_prune.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BINARY_DATA_PATH="/home/node/.n8n/binaryData/workflows"

# Find containers
DB_CONTAINER=$(docker ps --filter "name=srv-captain--n8n-db" --format "{{.ID}}" | head -n 1)
N8N_CONTAINER=$(docker ps --filter "name=srv-captain--n8n" --format "{{.ID}}" | grep -v n8n-db | head -n 1)

if [ -z "$DB_CONTAINER" ]; then
    echo "Error: Could not find n8n-db container."
    exit 1
fi
if [ -z "$N8N_CONTAINER" ]; then
    echo "Error: Could not find n8n container."
    exit 1
fi

# --- Step 1: Surgical row deletion ---
echo "Step 1: Running surgical row deletion..."
DELETED=$(cat "$DIR/prune.sql" | docker exec -i "$DB_CONTAINER" psql -U n8n -t -A -F'|')
ROW_COUNT=$(echo "$DELETED" | grep -c '|' || true)
echo "  Pruned $ROW_COUNT execution rows from database."

# --- Step 2: Delete binaryData for pruned executions ---
echo "Step 2: Deleting binaryData for pruned executions..."
BINARY_DELETED=0
while IFS='|' read -r exec_id workflow_id; do
    [ -z "$exec_id" ] && continue
    EXEC_PATH="$BINARY_DATA_PATH/$workflow_id/executions/$exec_id"
    if docker exec "$N8N_CONTAINER" test -d "$EXEC_PATH" 2>/dev/null; then
        docker exec "$N8N_CONTAINER" rm -rf "$EXEC_PATH"
        BINARY_DELETED=$((BINARY_DELETED + 1))
    fi
done <<< "$DELETED"
echo "  Removed binaryData for $BINARY_DELETED executions."

# --- Step 3: Orphan cleanup ---
# Find binaryData folders whose execution IDs no longer exist in the DB.
echo "Step 3: Scanning for orphaned binaryData folders..."

TMP_FOLDERS=$(mktemp)
TMP_DB_IDS=$(mktemp)
trap 'rm -f "$TMP_FOLDERS" "$TMP_DB_IDS"' EXIT

# Get all execution folder full paths from the n8n container
docker exec "$N8N_CONTAINER" find "$BINARY_DATA_PATH" -mindepth 3 -maxdepth 3 -type d 2>/dev/null > "$TMP_FOLDERS"

# Get all valid execution IDs from the DB
docker exec -i "$DB_CONTAINER" psql -U n8n -t -A -c "SELECT id FROM execution_entity;" > "$TMP_DB_IDS"

ORPHAN_COUNT=0
while IFS= read -r folder_path; do
    [ -z "$folder_path" ] && continue
    exec_id=$(basename "$folder_path")
    if ! grep -qx "$exec_id" "$TMP_DB_IDS"; then
        docker exec "$N8N_CONTAINER" rm -rf "$folder_path"
        ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    fi
done < "$TMP_FOLDERS"
echo "  Removed $ORPHAN_COUNT orphaned execution folders."

# --- Step 4: Remove empty workflow directories left behind ---
echo "Step 4: Cleaning up empty binaryData directories..."
docker exec "$N8N_CONTAINER" find "$BINARY_DATA_PATH" -mindepth 1 -type d -empty -delete 2>/dev/null
echo "  Done."

# --- Step 5: Reclaim disk space ---
echo "Step 5: Reclaiming disk space (VACUUM FULL)..."
docker exec -i "$DB_CONTAINER" psql -U n8n -c "VACUUM FULL execution_entity;"
docker exec -i "$DB_CONTAINER" psql -U n8n -c "VACUUM FULL execution_data;"

echo "Maintenance complete: $(date)"
