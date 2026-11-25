# PostgreSQL Docker Stack

A PostgreSQL stack for Docker Compose and Portainer Agent. The default image for a new cluster is `postgres:19.0-trixie`. The [PostgreSQL Ubuntu download page](https://www.postgresql.org/download/linux/ubuntu/) covers installation via `apt`. For this stack use the [Docker Official Image](https://hub.docker.com/_/postgres).

## Features

- Single `docker-compose.yml` with **no secrets** — everything via environment variables
- One DB server for **multiple projects** via a shared external network
- Persistent data in a bind-mounted directory (easy to back up and migrate)
- `initdb/` scripts run once on first start of an empty data directory
- Built-in healthcheck
- Port published on loopback by default, with remote access via SSH tunnel

## Requirements

- Docker Engine 28.0.0 or later for loopback-only publishing, with Docker Compose v2 or later
- Optional Portainer with a Docker Standalone environment connected through its Agent

## Quick start

```bash
mkdir -p data
(umask 077 && cp -n .env.example .env)
# Set POSTGRES_PASSWORD in .env before starting a fresh cluster.
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d
```

Compose creates `postgres-net` by default. Both bind-mount source directories must already exist. On first initialization the image requires a password from `POSTGRES_PASSWORD` or `POSTGRES_PASSWORD_FILE`. The example env publishes to host port `5434`. The Compose fallback when `POSTGRES_PORT_BIND` is unset is host port `5432`.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Superuser name |
| `POSTGRES_PASSWORD` | — | Superuser password; applied only on empty PGDATA |
| `POSTGRES_PASSWORD_FILE` | — | Path inside the container to a mounted password file. Set one password source |
| `POSTGRES_DB` | `postgres` | Default database created on empty PGDATA |
| `POSTGRES_IMAGE` | `postgres:19.0-trixie` | Image tag. On an existing cluster use a tag with the same major as `PG_VERSION` |
| `POSTGRES_NETWORK` | `postgres-net` | Network name for the DB server |
| `POSTGRES_NETWORK_EXTERNAL` | `false` | Use an existing external network |
| `POSTGRES_PORT_BIND` | `127.0.0.1:5432:5432` | Host→container port mapping (loopback only) |
| `POSTGRES_DATA_DIR` | `./data` | Data directory (use an absolute path in Portainer) |
| `POSTGRES_INITDB_DIR` | `./initdb` | Init scripts directory (use an absolute path in Portainer unless relative-path volumes are configured) |
| `POSTGRES_MEM_LIMIT` | `512m` | Container memory limit |
| `POSTGRES_CPU_LIMIT` | `1.0` | Container CPU limit |
| `POSTGRES_SHM_SIZE` | `256mb` | `/dev/shm` size |
| `PG_SHARED_BUFFERS` | `128MB` | `shared_buffers` |
| `PG_MAX_CONNECTIONS` | `100` | `max_connections` |
| `POSTGRES_INITDB_ARGS` | `--data-checksums` | `initdb` arguments (empty PGDATA only) |
| `INITDB_DATABASES` | — | Space-separated DB names created on empty PGDATA by `initdb/10-create-databases.sh` |

Initialization settings apply when a new cluster is created. Rotate an existing database password using `\password` in `psql` and update the credentials used by clients.

## Deployment

### Portainer Agent

1. Select the remote Docker environment in Portainer. For a new stack go to **Stacks → Add stack** and choose **Git Repository** or **Upload**. With Git, select the desired branch or tag and set the Compose path to `docker-compose.yml`. Update an existing stack in place.
2. On the server prepare the bind-mount directories, for example `/srv/postgres/data` and `/srv/postgres/initdb`. Put the contents of `initdb/` in the latter and keep `10-create-databases.sh` executable. On a fresh install leave `data` empty. For an existing stack use its current data mount source and check its `PG_VERSION` before editing the image tag.
3. If `POSTGRES_NETWORK_EXTERNAL=true`, create a bridge network with the exact name in `POSTGRES_NETWORK` in the remote environment's **Networks** page before deployment. Application stacks on the same Docker host can reference that network as external and reach the database at `postgres:5432`.
4. In the Portainer stack environment set `POSTGRES_DATA_DIR` and `POSTGRES_INITDB_DIR` to the literal absolute paths on the remote server. For example, `${HOME}` from the Mac cannot be used to select a home directory on the server. Enter the password and other variables or use **Load variables from .env file** with your private env file.
5. Deploy and verify the container health and application connections. For a deliberate image refresh, use **Re-pull image and redeploy** where available, or pull the target tag on the Docker host before redeploying.

The Docker daemon resolves bind mounts on the server running the Agent. For Git stacks, [Portainer Business Edition supports relative-path volumes](https://docs.portainer.io/advanced/relative-paths/). Keep persistent data outside the Git checkout. Deployment through the Agent uses its Docker connection. Create a personal SSH account only if you need separate interactive access.

### Docker CLI

```bash
docker compose --env-file myenv.env up -d
docker compose --env-file myenv.env down
```

## Security

- Keep credentials out of Git. An env file keeps values out of Compose source. Credentials passed as `POSTGRES_PASSWORD` are visible to principals with access to Docker container configuration.
- Restrict the local env file to its owner with `chmod 600`. Fresh clusters use SCRAM-SHA-256 for host authentication.
- Give each application its own database login and grant only the permissions it needs. Reserve the bootstrap superuser for administration.
- The default published port binds to server loopback. On [Docker Engine versions before 28.0.0](https://docs.docker.com/engine/network/port-publishing/), a host on the same L2 segment may still be able to reach a loopback-published port. For remote access use an SSH tunnel. This example assumes host port `5434` from `.env.example`. Change the last port in `-L` if the server uses a different published port.

```bash
ssh -fNT -o ExitOnForwardFailure=yes -L 127.0.0.1:5434:127.0.0.1:5434 user@host
psql -h 127.0.0.1 -p 5434 -U postgres
```

For file-based credentials on Docker Standalone, provision a password file on the Docker host with permissions restricted to the container entrypoint and administrators. Add this bind mount to the service's `volumes` in the deployed Compose definition, set `POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password`, and clear `POSTGRES_PASSWORD` in the stack variables. The mount keeps the password value out of the Docker container configuration.

```yaml
- type: bind
  source: /path/on/docker-host/postgres_password
  target: /run/secrets/postgres_password
  read_only: true
  bind:
    create_host_path: false
```

## Networking: one DB server for many projects

For independently managed application stacks, create the shared bridge network once on the Docker host. Use the same name in `POSTGRES_NETWORK` and in each application stack. For example, for a shared network called `db-net`, set these stack variables on the PostgreSQL stack:

```dotenv
POSTGRES_NETWORK=db-net
POSTGRES_NETWORK_EXTERNAL=true
```

In the application stack, add the shared network to the services that connect to PostgreSQL. In the example, `my-service` also stays on its project network. Add the `networks` block to an existing service definition:

```yaml
networks:
  db-net:
    external: true
    name: db-net

services:
  my-service:
    networks: [default, db-net]
```

Applications on the shared network connect to `postgres:5432` using the Compose service name and container port.

## Data directory

`POSTGRES_DATA_DIR` (default `./data`) holds all databases. Official images from 18 onward mount the parent at `/var/lib/postgresql`. PostgreSQL 19 stores the cluster in `19/docker` below that mount. Keep host path names stable across upgrades.

Before updating a live stack, inspect the active container's **Mounts** in Portainer and read `PG_VERSION` from the active `PGDATA`. Set `POSTGRES_IMAGE` to a release of that same major. If a running PostgreSQL 17 or earlier stack uses the official image's old layout, keep its existing Compose mount until the data migration.

An update within the same major uses the existing data directory. A major upgrade requires a dump and restore into a separate cluster, or a planned `pg_upgrade` with both versions available. Verify the backup by restoring it, then check the databases, roles, extensions, and application connections before switching traffic. Keep the previous cluster available for rollback until you validate the migration. See [Upgrading a PostgreSQL Cluster](https://www.postgresql.org/docs/19/upgrading.html).

For a physical copy to a compatible server within the same major, stop the database cleanly before copying the data directory and preserve ownership and permissions required by the target image. Include any tablespaces outside that directory.

## Backup & restore

Take backups outside the data directory. For a full migration, include global roles and tablespaces (`pg_dumpall --globals-only`) alongside per-database dumps. These examples use the SSH tunnel above and assume the target database already exists.

```bash
# backup one database (custom format, with compression)
pg_dump -h 127.0.0.1 -p 5434 -Fc -U postgres -d mydb -f mydb.dump

# restore
pg_restore -h 127.0.0.1 -p 5434 --exit-on-error -U postgres -d mydb mydb.dump

# plain SQL dump / restore
pg_dump -h 127.0.0.1 -p 5434 -U postgres -d mydb > mydb.sql
psql -h 127.0.0.1 -p 5434 -v ON_ERROR_STOP=1 -U postgres -d mydb < mydb.sql
```

See the official documentation: [PostgreSQL Backup and Restore](https://www.postgresql.org/docs/current/backup-dump.html), [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html), [pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html).

## initdb

Place `*.sql` or `*.sh` files in the directory mounted at `/docker-entrypoint-initdb.d`. This is `./initdb` by default and `POSTGRES_INITDB_DIR` for the remote profile. Files run in name order when a new cluster is initialized. See [initdb/README.md](initdb/README.md) for partial startup failures.

```sql
CREATE DATABASE first_db;
CREATE DATABASE second_db;
```

To create databases from a list without hardcoding names in the repo, set the
`INITDB_DATABASES` variable (space-separated names in your env file). The bundled
`initdb/10-create-databases.sh` then creates the missing ones on first start.
