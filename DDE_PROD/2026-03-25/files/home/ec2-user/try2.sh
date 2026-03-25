#!/usr/bin/env bash
set -euo pipefail

infile="importLOADERerror_data.txt"

# UTF-8 bytes for U+2502 BOX DRAWINGS LIGHT VERTICAL (│)
awk -v pipe="$(printf '\342\224\202')" -f /dev/stdin "$infile" <<'AWK'
BEGIN { FS = "[[:space:]]*" pipe "[[:space:]]*" }

function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

{
  batch = trim($3)
  deal  = trim($4)
  msg   = trim($5)
  errid = trim($6)
  user  = trim($7)

  # Escape single quotes for SQL: ' -> ''
  #gsub(/\047/, "\047\047", msg)
  #gsub(/\047/, "\047\047", msg)

  fdate = substr(trim($1), 1, 10)

  printf "INSERT INTO dl_triage (batch_no, err_dealsheet_no, err_message, err_id, failure_date, date_updated, username, status, failure_count, retry_count, retry_date, is_active, date_inserted) "
  printf "VALUES ('%s', '%s', '%s', '%s', '%s', NULL, '%s', NULL, 1, 0, NULL, 1, CURRENT_TIMESTAMP);\n",
         batch, deal, msg, errid, fdate, user
}
AWK


