#!/bin/bash
# ~/pruner4n8n/run_prune.sh

# Get the directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Find the current container ID for the n8n-db service
# We use --filter to find the name and head to grab the most recent instance
CONTAINER_ID=$(docker ps --filter "name=srv-captain--n8n-db" --format "{{.ID}}" | head -n 1)

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Could not find n8n-db container."
    exit 1
fi

echo "Step 1: Running surgical row deletion..."
cat "$DIR/prune.sql" | docker exec -i "$CONTAINER_ID" psql -U n8n

echo "Step 2: Reclaiming disk space (VACUUM FULL)..."
docker exec -i "$CONTAINER_ID" psql -U n8n -c "VACUUM FULL execution_data;"

echo "Maintenance complete: $(date)"

