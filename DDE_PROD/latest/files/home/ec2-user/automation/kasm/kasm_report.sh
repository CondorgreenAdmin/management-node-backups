#!/bin/bash

cd ~/automation/kasm/
source ~/paths/MYSQL_PATH

#Path to the MySQL extra defaults file
DEFAULTS_FILE="dde_db.cnf"
DB_NAME="DDE-prd"
#cycle_id="${CYCLE_ID:-$(date +%Y%m)}"
cycle_id="202512"

# 1 Retrieve Total Headline Deals
total_headline_deals=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
    "SET @in_cycle_id = '$cycle_id'; SELECT COUNT(*) AS \"All Headline Deals\" FROM dsh_headlines WHERE cycle_id = @in_cycle_id;")

# 2 To verify how headline deals are distributed across channels.
headline_deals_per_channel=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
    "SET @in_cycle_id = '$cycle_id'; \
     SELECT h.channel_id, COALESCE(c.channel_name, 'Generics') AS channel_name, COUNT(*) AS \"All headline deals per channel\" \
     FROM dsh_headlines h \
     LEFT JOIN cfg_channels c \
         ON h.channel_id = c.channel_id \
     WHERE h.cycle_id = @in_cycle_id \
     GROUP BY h.channel_id, c.channel_name \
     ORDER BY h.channel_id;")

# Build XLSX with heading + data for total_headline_deals and step 2
output_xlsx="${OUTPUT_XLSX:-kasm_report_${cycle_id}.xlsx}"
total_headline_deals="$total_headline_deals" headline_deals_per_channel="$headline_deals_per_channel" output_xlsx="$output_xlsx" python3 - <<'PY'
import os
import sys

try:
    from openpyxl import Workbook
    from openpyxl.styles import PatternFill, Font, Border, Side
except Exception as exc:
    print(f"Missing dependency: openpyxl ({exc})", file=sys.stderr)
    sys.exit(1)

total_headline_deals = os.environ.get("total_headline_deals", "").strip()
headline_deals_per_channel = os.environ.get("headline_deals_per_channel", "").strip()
output_xlsx = os.environ.get("output_xlsx", "kasm_report.xlsx")

wb = Workbook()
ws = wb.active

heading_fill = PatternFill(start_color="FF0000", end_color="FF0000", fill_type="solid")
heading_font = Font(color="FFFFFF", bold=True)
border_side = Side(style="thin", color="000000")
cell_border = Border(left=border_side, right=border_side, top=border_side, bottom=border_side)

ws["A1"] = "All Headline Deals"
ws["A1"].fill = heading_fill
ws["A1"].font = heading_font
ws["A2"] = total_headline_deals
ws["A1"].border = cell_border
ws["A2"].border = cell_border

# Step 2 header (one row lower than previous section)
ws["A4"] = "Channel ID"
ws["B4"] = "Channel Name"
ws["C4"] = "All headline deals per channel"
for cell in ("A4", "B4", "C4"):
    ws[cell].fill = heading_fill
    ws[cell].font = heading_font

row_idx = 5
if headline_deals_per_channel:
    for line in headline_deals_per_channel.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            parts = (parts + ["", "", ""])[:3]
        ws.cell(row=row_idx, column=1, value=parts[0])
        ws.cell(row=row_idx, column=2, value=parts[1])
        ws.cell(row=row_idx, column=3, value=parts[2])
        row_idx += 1

# Set A, B, C to ~240px width (approximate Excel character width)
col_width = (240 - 5) / 7.0
for col in ("A", "B", "C"):
    ws.column_dimensions[col].width = col_width

wb.save(output_xlsx)
PY

# 3 To identify headline deals that have not been approved
not_approved_deals=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SET @in_cycle_id = '$cycle_id'; \
SELECT COUNT(*) AS \"Not Approved Deals\" \
FROM dsh_headlines \
WHERE cycle_id = @in_cycle_id \
AND deal_status != 25;")

# 4 To validate total generated channel deals per business channel
channel_deals_per_channel=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SET @in_cycle_id = '$cycle_id'; \
SELECT channel_name, COUNT(*) AS \"All Deals Per Channel\" \
FROM dsh_channel_deals_hist \
WHERE cycle_id = @in_cycle_id \
GROUP BY channel_name;")

# 5 Reconfirm channel-level distribution using historical deal data
historical_deals_per_channel=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SET @in_cycle_id = '$cycle_id'; \
SELECT channel_name, COUNT(*) AS \"All Deals Per Channel\" \
FROM dsh_channel_deals_hist \
WHERE cycle_id = @in_cycle_id \
GROUP BY channel_name;")

# 6 Validate campaign configuration and Channel 9 custom deals
campaigns_cycle=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SELECT * FROM \`$DB_NAME\`.enr_campaigns \
WHERE deal_set_type_id = '4' \
AND campaign_id LIKE CONCAT('$cycle_id', '%');")

channel9_deals=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SELECT * FROM dsh_channel_deals \
WHERE campaign_id LIKE CONCAT('$cycle_id', '%') \
AND channel_id = '9';")

channel9_dealsheet_count=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SELECT DISTINCT COUNT(ds_sheet_no) \
FROM dl_stg_epx_ds_dealsh \
WHERE ds_sheet_no IN ( \
    SELECT dealsheet_no \
    FROM dsh_channel_deals \
    WHERE campaign_id LIKE CONCAT('$cycle_id', '%') \
    AND channel_id = '9' \
);")

# 7 Validate individual deal records contain required identifiers
channel9_deal_records=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SELECT * FROM dsh_channel_deals \
WHERE campaign_id LIKE CONCAT('$cycle_id','%') \
AND channel_id = '9';")

# 8 Final confirmation of custom deal sheets created for Channel 9
final_dealsheet_count=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
"SELECT DISTINCT COUNT(ds_sheet_no) \
FROM dl_stg_epx_ds_dealsh \
WHERE ds_sheet_no IN ( \
    SELECT dealsheet_no \
    FROM dsh_channel_deals \
    WHERE campaign_id LIKE CONCAT('$cycle_id','%') \
    AND channel_id = '9' \
);")
