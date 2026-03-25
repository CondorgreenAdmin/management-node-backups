#!/bin/bash
 
input_file="$1"
output_file="$2"
target_table="$3"      # e.g. siebel.CX_DDE_DEALS
sequence_name="$4"     # e.g. C3D_DDE_DEALS_SEQ
table_name="$5"        #e.g dl_siebel_deals_psv
old_batch_no="$6"
new_batch_no="$7"
 
 
if [[ -z "$input_file" || -z "$output_file" || -z "$target_table" || -z "$sequence_name" ]]; then
    echo "Usage: $0 <input.sql> <output.sql> <target_table> <sequence_name>"
    exit 1
fi
 
while IFS= read -r line; do
    # Replace MySQL table with Siebel table
    line=$(echo "$line" \
        | sed "s/INSERT INTO \`$table_name/INSERT INTO $target_table/")
 
    # Add ROW_ID as first column
    line=$(echo "$line" \
        | sed "s/(/(ROW_ID, /")
 
    # Add sequence NEXTVAL as first value
    line=$(echo "$line" \
        | sed "s/VALUES(/VALUES($sequence_name, /")
 
    # Replace batch number
    line=$(echo "$line" \
        | sed "s/$old_batch_no/$new_batch_no/g")
 
    echo "$line"
done < "$input_file" > "$output_file"




INSERT INTO dl_stg_siebel_deals_psv (business_unit,channel_name,cycle_id,batch_no,add_user,add_datetime,dealsheet_no,dealsheet_description,cash,total_sub,subs,upg_act,channel_type,finance_period,contract_months,fin,from_date,end_date,account_number,MSISDN,no_of_imeis) VALUES ('CBU','NATIONAL CHAINS',202511,'20251106154126CBU3B','8','2025-11-06 13:41:27','V35KB00067','Acer Aspire Core i3 512GGB SSD + Vodacom X25 MAX 2 5G CPE + 5GB VID TKT X 3 @ R989.00PM (R490 Finance + R499 Reduced Subs) on Home Internet 30Mbps FUP',0.00,989.00,658.00,'Both','General',490.00,24,'Y','2025-11-07','2025-12-08',NULL,NULL,1);

INSERT INTO dl_stg_siebel_deals_psv (business_unit,channel_name,cycle_id,batch_no,add_user,add_datetime,dealsheet_no,dealsheet_description,cash,total_sub,subs,upg_act,channel_type,finance_period,contract_months,fin,from_date,end_date,account_number,MSISDN,no_of_imeis) VALUES ('CBU','NATIONAL CHAINS',202511,'20251106154126CBU3B','8','2025-11-06 13:41:27','V35KB00077','HUAWEI Matebook D14 2024 i3 8/512GB + Vodacom X25 MAX 2 5G CPE + 5GB VID TKT X 3 @ R1099.00PM (R600 Finance + R499 Reduced Subs) on Home Internet 30Mbps FUP',0.00,1099.00,658.00,'Both','General',600.00,24,'Y','2025-11-07','2025-12-08',NULL,NULL,1);



INSERT INTO siebel.CX_DDE_DEALS (ROW_ID, CREATED_BY, LAST_UPD_BY, BATCH_NO, DEALSHEET_NO, SUB_BATCH_NO, FINANCED_DEAL, ACCOUNT_ID, CHANNEL, CONTRACT_PERIOD, CYCLE_ID, DEALSHEET_DESCRIPTION, EMI, END_DT, HANDSET_COUNT, MSISDN, OPERATION, REWARD_TYPE, START_DT, TOT_BASE_MRC, TOT_MRC, TOT_ONCE_OFF) VALUES(siebel.C3D_DDE_DEALS_SEQ.NEXTVAL, '8', '8', '20260102205756CBU1B', 'DV5LC08604', 'SB-20260102205756CBU1B-0', 'Y', NULL, 'DIRECT', '24', '202512', 'Samsung Galaxy A26 128GB 5G x 2 + Bonus Video Ticket 5GB 3 Months + Promotional 30GB - Once Off - Topup @ R994.00PM (R304 Finance + R690 Subs) on Red Flexi 690 Plan +  PMFL8524 (24 months) - TOTAL R1079.00PM', '304.00', '05/02/2026', 2, NULL, 'Both', 'General', '09/12/2025', 994.00, 690.00, 0.00);
i
INSERT INTO siebel.CX_DDE_DEALS (ROW_ID, CREATED_BY, LAST_UPD_BY, BATCH_NO, DEALSHEET_NO, SUB_BATCH_NO, FINANCED_DEAL, ACCOUNT_ID, CHANNEL, CONTRACT_PERIOD, CYCLE_ID, DEALSHEET_DESCRIPTION, EMI, END_DT, HANDSET_COUNT, MSISDN, OPERATION, REWARD_TYPE, START_DT, TOT_BASE_MRC, TOT_MRC, TOT_ONCE_OFF) VALUES(siebel.C3D_DDE_DEALS_SEQ.NEXTVAL, '8', '8', '20260102205756CBU1B', 'DV5LC08605', 'SB-20260102205756CBU1B-0', 'Y', NULL, 'DIRECT', '24', '202512', 'Oppo Reno 13F 512GB 5G x 2 + Bonus Video Ticket 5GB 3 Months + Promotional 30GB - Once Off - Topup @ R1514.00PM (R824 Finance + R690 Subs) on Red Flexi 690 Plan +  PMFL8524 (24 months) - TOTAL R1599.00PM', '824.00', '05/02/2026', 2, NULL, 'Both', 'General', '09/12/2025', 1514.00, 690.00, 0.00);





FROM dl_stg_siebel_deals_psv SC
FROM dl_stg_siebel_components_psv SC
FROM dl_stg_siebel_multiline_psv SC
FROM dl_stg_siebel_promos_psv SC
FROM dl_stg_siebel_rules_psv SC
