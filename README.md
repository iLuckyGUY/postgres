# PostgreSQL Docker Stack

A universal, project-agnostic PostgreSQL stack for Docker. Deploy on any server or locally, and configure databases, network, resources and limits through environment variables — nothing is hardcoded.

## Features

- Single `docker-compose.yml` with **no secrets** — everything via environment variables
- One DB server for **multiple projects** via a shared external network
- Persistent data in a bind-mounted directory (easy to back up and migrate)
- `initdb/` scripts run once on first start of an empty data directory
- Built-in healthcheck
- Port published on loopback only; remote access via SSH tunnel

## Requirements

- Docker Engine 20+ with Compose v2
- Optional: Portainer for GitOps deployment

## Quick start

```bash
cp .env.example .env   # fill in values
docker compose --env-file .env up -d
```

Without an env file the compose file is self-sufficient: it creates the `postgres-net` network and `./data` directory.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Superuser name |
| `POSTGRES_PASSWORD` | — | Superuser password; applied only on empty PGDATA |
| `POSTGRES_DB` | `postgres` | Default database created on empty PGDATA |
| `POSTGRES_IMAGE` | `postgres:latest` | Image tag (keep on the cluster major) |
| `POSTGRES_NETWORK` | `postgres-net` | Network name for the DB server |
| `POSTGRES_NETWORK_EXTERNAL` | `false` | Use an existing external network |
| `POSTGRES_PORT_BIND` | `127.0.0.1:5432:5432` | Host→container port mapping (loopback only) |
| `POSTGRES_DATA_DIR` | `./data` | Data directory (use an absolute path in Portainer) |
| `POSTGRES_MEM_LIMIT` | `512m` | Container memory limit |
| `POSTGRES_CPU_LIMIT` | `1.0` | Container CPU limit |
| `POSTGRES_SHM_SIZE` | `256mb` | `/dev/shm` size |
| `PG_SHARED_BUFFERS` | `128MB` | `shared_buffers` |
| `PG_MAX_CONNECTIONS` | `100` | `max_connections` |
| `POSTGRES_INITDB_ARGS` | `--data-checksums` | `initdb` arguments (empty PGDATA only) |

> `POSTGRES_PASSWORD` and `POSTGRES_INITDB_ARGS` take effect **only on an empty
> data directory** (first start). On an existing cluster the values are ignored.

## Deployment

### Portainer (GitOps)

1. Stacks → Add stack.
2. Repository → this repo, compose file `docker-compose.yml`.
3. Fill the environment variables from your local env file.
4. Use an **absolute** `POSTGRES_DATA_DIR` path for the bind mount.
5. Deploy.

### Docker CLI

```bash
docker compose --env-file myenv.env up -d
docker compose --env-file myenv.env down
```

## Security

- No secrets are stored in the repository. Values live in a **local** env file (excluded by `.gitignore`) and are provided at deploy time.
- The only committed env file is `.env.example` with placeholders.
- The published port is bound to `127.0.0.1`; for remote access use an SSH tunnel:

```bash
ssh -L 5434:127.0.0.1:5434 user@host
psql -h 127.0.0.1 -p 5434 -U postgres
```

## Networking: one DB server for many projects

The DB server lives on a stable infrastructure network, and projects join it from their own compose files. The DB stack does not list projects — a new project must not require redeploying the DB server.

```yaml
networks:
  default:
    name: ${POSTGRES_NETWORK:-postgres-net}
    external: ${POSTGRES_NETWORK_EXTERNAL:-false}
```

Project side — add the DB network to the services that need it:

```yaml
networks:
  db-net:
    external: true
    name: db-net

services:
  my-service:
    networks: [my-net, db-net]
```

Services reach the database by `PostgreSQL` (container_name) inside that network.

## Data directory

`POSTGRES_DATA_DIR` (default `./data`) holds all databases. To migrate to another server:

```bash
docker compose --env-file myenv.env down
tar -czf data.tar.gz data/
```

On the target server: extract to the same path (or set `POSTGRES_DATA_DIR`), `chown -R 999:999 <dir>`, and use an image whose major is `>=` the cluster major (from `PG_VERSION`). An existing cluster is **not** reinitialized on start.

## Backup & restore

```bash
# backup one database (custom format, with compression)
pg_dump -Fc -U postgres -d mydb -f mydb.dump

# restore
pg_restore -U postgres -d mydb mydb.dump

# plain SQL dump / restore
pg_dump -U postgres -d mydb > mydb.sql
psql -U postgres -d mydb < mydb.sql
```

See the official documentation: [PostgreSQL Backup and Restore](https://www.postgresql.org/docs/current/backup-dump.html), [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html), [pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html).

## initdb

Place `*.sql` / `*.sh` files into `initdb/` — they run once, in name order, on the first start of an **empty** data directory.

```sql
CREATE DATABASE first_db;
CREATE DATABASE second_db;
```
