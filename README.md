![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)
![n8n](https://img.shields.io/badge/n8n-compatible-orange.svg)
![Postgres](https://img.shields.io/badge/PostgreSQL-15+-blue.svg)

# pruner4n8n: Surgical n8n Database Pruning

A specialized maintenance utility for n8n instances running on Docker (specifically optimized for CapRover/Swarm environments).

## The Problem
n8n's global pruning (`N8N_EXECUTIONS_DATA_PRUNE`) is a blunt instrument. It deletes the oldest records regardless of their importance. If you have a high-frequency "heartbeat" flow (e.g., every 1 minute), it will quickly push out the execution history of your more critical, less frequent flows.

## The Solution
This "Surgical Pruner" applies logic that n8n's native janitor lacks:
1. **Activity-Based Shielding**: It ignores workflows you have modified recently (default: 7 days), ensuring you have full history while actively developing/debugging.
2. **Status-Aware Retention**: It keeps a specific number of both `success` AND `failed` executions (default: 10 each) per workflow, so you never lose your "last known good" or "last known error" states.
3. **Space Reclamation**: It runs a non-blocking `VACUUM` to keep the filesystem footprint lean on storage-constrained devices like the Raspberry Pi.

## Configuration

The maintenance suite relies on a local `env` file to handle database credentials securely. 

1. **Create your secrets file**:
   ```bash
   cp env.example env
   nano env
   ```
2. **Fill in your details**:
   - `N8N_POSTGRESDB_USER`: Your n8n database username.
   - `N8N_POSTGRESDB_PASSWORD`: Your n8n database password.
   - `N8N_POSTGRESDB_DATABASE`: Your database name (usually `n8n`).

*Note: The `env` file is ignored by Git to keep your credentials safe.*

## Features (Updated)

- **Hourly Execution**: Now runs every hour to keep the database size "pinned" at its minimum.
- **Surgical Row Deletion**: Keeps exactly 10 `success` and 10 `failed` executions per workflow.
- **Development Shielding**: Workflows modified within the last 7 days are ignored, preserving full history during active coding sessions.
- **Aggressive Reclaiming**: Automatically runs `VACUUM FULL` after every prune to return disk space to the OS immediately.
- **Multi-Core Backups**: Includes a manual backup script that utilizes `lbzip2` for high-speed, parallel compression.

## Files
- `prune.sql`: The logic engine. Uses PostgreSQL Window Functions to partition and rank executions.
- `run_prune.sh`: The execution wrapper. Dynamically finds the active `n8n-db` container and pipes the SQL in.
- `setup.sh`: The installer. Sets up the Systemd Service and Timer.
- `backup_n8n.sh`: A manual backup script. Assumes lbzip2 is installed.

## Installation
1. Clone this repo to `~/pruner4n8n/`.
2. Make the scripts executable:
   ```bash
   chmod +x run_prune.sh setup.sh
   ```
3. Run the setup script:
   ```bash
   ./setup.sh
   ```

## Generic Docker Setup (Non-CapRover)

If you are not using CapRover, this script still works as long as your database is in a Docker container.

1. Ensure your database container has a label or name containing `n8n-db`.
2. The `run_prune.sh` script dynamically finds the container ID using:
   `docker ps --filter "name=n8n-db"`
3. If your container name is different (e.g., `postgres_db`), simply update the filter in `run_prune.sh`.

## Manual Usage
To run a prune immediately without waiting for the timer:
```bash
./run_prune.sh
```

## Manual Backup

While the pruner runs automatically, you can take a manual, versioned snapshot of your database at any time (e.g., before an n8n upgrade).

```bash
./backup_n8n.sh
```
This will create a file named `n8n_backup_YYYY-MM-DD.sql.bz2` in the current directory. On a pruned database, these files are typically **95% smaller** than unoptimized dumps.

## Logs
View the history of the pruner's activity via the system journal:
```bash
journalctl -u n8n-pruner
```

## Disclaimer

**USE AT YOUR OWN RISK.** This script performs `DELETE` and `VACUUM FULL` operations on your database. While designed to be surgical, always ensure you have a fresh backup (via `backup_n8n.sh`) before running maintenance for the first time or after major n8n updates.
