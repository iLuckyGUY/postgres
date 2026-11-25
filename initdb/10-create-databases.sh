#!/bin/bash
# Auto-create databases listed in $INITDB_DATABASES (space-separated) on a fresh,
# empty PGDATA. Runs ONCE at the first start of a new instance; existing data is
# never touched. Keep this script generic — database names come from env, never
# hardcode them here.
set -euo pipefail
set -f

[ -z "${INITDB_DATABASES:-}" ] && exit 0

for db in ${INITDB_DATABASES}; do
  psql --no-psqlrc --set=ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=db="$db" <<'SQL'
SELECT format('CREATE DATABASE %I', :'db')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db')
\gexec
SQL
done
