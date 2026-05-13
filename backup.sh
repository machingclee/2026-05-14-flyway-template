#!/usr/bin/env bash
# Backup the MySQL database defined in flyway.conf using Docker (no local MySQL client needed).
# Usage: ./backup.sh [output-dir]
# Output: <output-dir>/backup_<db>_<timestamp>.sql.gz  (default: current directory)

set -euo pipefail

CONF="$(dirname "$0")/flyway.conf"
OUT_DIR="${1:-.}"

# ---------------------------------------------------------------------------
# Parse flyway.conf
# ---------------------------------------------------------------------------
get_prop() {
  grep -E "^$1=" "$CONF" | head -1 | cut -d= -f2-
}

JDBC_URL=$(get_prop "flyway.url")
DB_USER=$(get_prop "flyway.user")
DB_PASS=$(get_prop "flyway.password")

# ---------------------------------------------------------------------------
# Extract host, port, database from JDBC URL
# jdbc:mysql://HOST:PORT/DATABASE?params
# ---------------------------------------------------------------------------
WITHOUT_PREFIX="${JDBC_URL#jdbc:mysql://}"
HOST_PORT_DB="${WITHOUT_PREFIX%%\?*}"   # strip ?query params
HOST_PORT="${HOST_PORT_DB%%/*}"         # HOST:PORT
DB_NAME="${HOST_PORT_DB#*/}"            # database name
DB_HOST="${HOST_PORT%%:*}"
DB_PORT="${HOST_PORT##*:}"

# ---------------------------------------------------------------------------
# Run backup
# ---------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_FILE="${OUT_DIR}/backup_${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "Host    : ${DB_HOST}:${DB_PORT}"
echo "Database: ${DB_NAME}"
echo "User    : ${DB_USER}"
echo "Output  : ${OUT_FILE}"
echo ""

# MYSQL_PWD avoids the password appearing in process list (ps aux)
docker run --rm \
  -e MYSQL_PWD="${DB_PASS}" \
  mysql:8.0 \
  mysqldump \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --single-transaction \
    --routines \
    --triggers \
    "${DB_NAME}" \
  | gzip > "${OUT_FILE}"

echo "Backup complete: ${OUT_FILE}"
