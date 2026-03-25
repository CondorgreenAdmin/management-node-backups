#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/vb_templates

#CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"
#CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"

DTE=$(date +"%Y-%m-%d-%H-%M-%S")

NNAME=$(echo "VB_TEMPLATE_FOR_AGENTS_"$DTE".xlsx")

aws s3 cp VB_TEMPLATE_FOR_AGENTS.xlsx s3://prd-dde-share/xls_ingestion/Templates/backups/$NNAME

mv VB_TEMPLATE_FOR_AGENTS.xlsx versions/$NNAME

#DL="arnulf.hanauer@vcontractor.co.za,yusuf.pinn@vcontractor.co.za,olwethu.ketwa@vcontractor.co.za,lukhanyo.vakele@vcontractor.co.za"
DL="arnulf.hanauer@vcontractor.co.za"

echo -e "PRODUCTION VB templates on date: $DTE uploaded to DDE templates in S3. "  | mutt -s "DDE(PROD) VB_template uploaded: $DTE" -- $DL 

