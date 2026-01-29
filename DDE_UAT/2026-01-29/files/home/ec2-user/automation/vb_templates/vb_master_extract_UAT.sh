#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/vb_templates

#CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"
CNF="/home/ec2-user/automation/rotations/dde-uat-admin.cnf"

DTE=$(date +"%Y-%m-%d-%H-%M-%S")


mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./vb_tariffs.sql | sed 's/\t/|/g' | sed 's/NULL//g' > VB_template_tariffs.csv
RC_T=$?
CNT_T=$(cat VB_template_tariffs.csv | wc -l)

mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./vb_devices.sql | sed 's/\t/|/g' | sed 's/NULL//g' > VB_template_devices.csv
RC_D=$?
CNT_D=$(cat VB_template_devices.csv | wc -l)

mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./vb_accessories.sql | sed 's/\t/|/g' | sed 's/NULL//g' > VB_template_accessories.csv
RC_A=$?
CNT_A=$(cat VB_template_accessories.csv | wc -l)

mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./vb_vases.sql | sed 's/\t/|/g' | sed 's/NULL//g' > VB_template_vases.csv
RC_V=$?
CNT_V=$(cat VB_template_vases.csv | wc -l)

aws s3 cp . s3://dev-dopadde-share/xls_ingestion/vb_transfers/ --recursive --exclude "*" --include "VB_template_*"
RC_S3=$?


#DL="arnulf.hanauer@vcontractor.co.za,yusuf.pinn@vcontractor.co.za,olwethu.ketwa@vcontractor.co.za,lukhanyo.vakele@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"
DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)
echo -e "New VB templates generated on $DTE. \n\n Return codes/counts were\n\nTariffs: $RC_T    $CNT_T \n\nDevices: $RC_D     $CNT_D \n\nAccessories: $RC_A     $CNT_A \n\nVases: $RC_V     $CNT_V \n\nAWS S3: $RC_S3\n" | mutt -s "DDE(UAT) VB_template generated: $DTE" -- $DL 

