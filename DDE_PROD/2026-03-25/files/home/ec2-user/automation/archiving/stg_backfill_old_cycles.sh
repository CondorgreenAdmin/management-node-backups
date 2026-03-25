#!/usr/bin/env bash
#set -euo pipefail

cd ~/automation/archiving

CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"

export PATH=/usr/local/bin/$PATH

# Edit to match your environment or export these before running:
#HOST="${HOST:-your-mysql-host}"
#PORT="${PORT:-3306}"
#USER="${USER:-your-user}"
DB="DDE-prd"
#PASS_OPTS="${PASS_OPTS:-}"   # prefer ~/.my.cnf
#PREFIXES=("dl_stg_epx" "dl_stg_sie")

# How old is "old"
OLDER_THAN_MONTHS="${OLDER_THAN_MONTHS:-18}"

mysql_cmd() {
  #mysql -h "$HOST" -P "$PORT" -u "$USER" $PASS_OPTS --protocol=tcp \
  #  --default-character-set=utf8mb4 "$@"
  mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 "$@"

}

# Compute cutoff YYYYMM (older than N months)
CUTOFF_YYYYMM="$(mysql_cmd -N -s "$DB" -e "SELECT EXTRACT(YEAR_MONTH FROM (CURRENT_DATE - INTERVAL ${OLDER_THAN_MONTHS} MONTH));")"
echo "Cutoff: cycle_id < $CUTOFF_YYYYMM (older than ${OLDER_THAN_MONTHS} months)"

prefix_list=$(printf "'%s'," "${PREFIXES[@]}")
prefix_list="${prefix_list%,}"

# Discover distinct old cycle_ids across ALL matching tables.
# We do it safely via dynamic UNION of "SELECT DISTINCT cycle_id FROM <table> WHERE cycle_id < cutoff"
TABLES="$(mysql_cmd -N -s "$DB" -e "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = DATABASE()
     AND (LEFT(table_name, 10) IN ('dl_stg_epx', 'dl_stg_sie') OR TABLE_NAME LIKE 'dl_siebel_%sub_batched')
  ORDER BY table_name;
")"

if [[ -z "${TABLES// }" ]]; then
  echo "No tables matched prefixes; exiting."
  exit 1
fi

# Build the UNION ALL query text in bash (18 tables => totally fine)
UNION_SQL=""
first=1
while read -r t; do
  [[ -z "$t" ]] && continue
  piece="SELECT DISTINCT cycle_id FROM \`$t\` WHERE cycle_id IS NOT NULL AND cycle_id < ${CUTOFF_YYYYMM}"
  if [[ $first -eq 1 ]]; then
    UNION_SQL="$piece"
    first=0
  else
    UNION_SQL="${UNION_SQL} UNION ALL ${piece}"
  fi
done <<< "$TABLES"

CYCLES="$(mysql_cmd -N -s "$DB" -e "SELECT DISTINCT cycle_id FROM (${UNION_SQL}) x ORDER BY cycle_id;")"

if [[ -z "${CYCLES// }" ]]; then
  echo "No old cycles found."
  exit 0
fi

echo "Old cycles found:"
echo "$CYCLES" | sed 's/^/  - /'

# Run one cycle at a time, preserving per-cycle naming conventions
while read -r c; do
  [[ -z "$c" ]] && continue
  echo "=== Backfill cycle_id=$c ==="
  ./stg_archive_cycle_to_s3.sh "$c"
  sleep 5
done <<< "$CYCLES"

echo "Backfill complete."
