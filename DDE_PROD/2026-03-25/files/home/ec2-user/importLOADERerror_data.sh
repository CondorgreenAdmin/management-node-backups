export PATH=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

export CNF=./automation/rotations/dde-prd-admin.cnf

#mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "select * from dl_triage"
#

#cat importLOADERerror_data.txt | head | awk '{print substr($0, index($0,$2))}' | awk -v FS=$'\xE2\x94\x82' '{print "INSERT INTO dl_triage (batch_no ,err_dealsheet_no ,err_message ,err_id ,failure_date ,date_updated ,username ,status ,failure_count ,retry_count ,retry_date ,is_active ,date_inserted) VALUES (",$3","$4","$5,",",$6,",","2026-02-03",",","NULL",",",$7,",","NULL",",",1,",",0,",","NULL",",",1,",","CURRENT_TIMESTAMP",");"}'
#cat importLOADERerror_data.txt | head | awk '{print substr($0, index($0,$2))}' | awk -v FS=$'\xE2\x94\x82' '{$1=$1; print $0}'| awk '{print $2}'

#INSERT INTO dl_triage (batch_no ,err_dealsheet_no ,err_message ,err_id ,failure_date ,date_updated ,username ,status ,failure_count ,retry_count ,retry_date ,is_active ,date_inserted) VALUES (
#
#
./try2.sh | sed "s/''/'/g" > insert.sql

mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 < insert.sql


