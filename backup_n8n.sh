#!/bin/bash
# ~/n8ndump/backup_n8n.sh

# Get the script's actual directory to keep paths relative
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source the DB credentials from the local env file
if [ -f "$DIR/env" ]; then
    source "$DIR/env"
else
    echo "Error: env file not found in $DIR"
    exit 1
fi

# Find the active n8n-db container
CONTAINER_ID=$(docker ps --filter "name=srv-captain--n8n-db" --format "{{.ID}}" | head -n 1)

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Could not find n8n-db container."
    exit 1
fi

BACKUP_NAME="n8n_backup_$(date +%F).sql.bz2"
echo "Creating compressed backup: $BACKUP_NAME"

# Perform dump and pipe through multi-core compression
docker exec -i "$CONTAINER_ID" pg_dump -U "$N8N_POSTGRESDB_USER" "${N8N_POSTGRESDB_DATABASE:-n8n}" | \
lbzip2 -9 > "$DIR/$BACKUP_NAME"

echo "Backup complete! Current size: $(du -h "$DIR/$BACKUP_NAME" | cut -f1)"
