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

## Files
- `prune.sql`: The logic engine. Uses PostgreSQL Window Functions to partition and rank executions.
- `run_prune.sh`: The execution wrapper. Dynamically finds the active `n8n-db` container and pipes the SQL in.
- `setup.sh`: The installer. Sets up the Systemd Service and Timer.

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

## Manual Usage
To run a prune immediately without waiting for the timer:
```bash
./run_prune.sh
```

## Logs
View the history of the pruner's activity via the system journal:
```bash
journalctl -u n8n-pruner
```

