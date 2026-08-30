#!/bin/bash
# Auto-create databases listed in $INITDB_DATABASES (space-separated) on a fresh,
# empty PGDATA. Runs ONCE at the first start of a new instance; existing data is
# never touched. Keep this script generic — database names come from env, never
# hardcode them here.
set -euo pipefail

[ -z "${INITDB_DATABASES:-}" ] && exit 0

for db in ${INITDB_DATABASES}; do
  if ! psql -U "${POSTGRES_USER:-postgres}" -Atqc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
    echo "[initdb] creating database ${db}"
    createdb -U "${POSTGRES_USER:-postgres}" "${db}"
  else
    echo "[initdb] database ${db} already exists"
  fi
done