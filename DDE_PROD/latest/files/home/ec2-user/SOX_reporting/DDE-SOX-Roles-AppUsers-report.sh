#!/bin/bash

cd SOX_reporting/

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

DTE=$(date +"%Y-%m-%d")
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, blaine.simpson@vcontractor.co.za, khanya.mankosi@vcontractor.co.za, yamkela.matolengwe@condorgreen.com" 
#SOXDL="$DL, Jeanine.DuToit@vodacom.co.za, Atiyyah.Kajee@vodacom.co.za"

SOXDL=$DL

#Get DDE application users
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_sox_user_role_mappings" --batch --raw | sed 's/\t/,/g' > DDE-PRD-Roles-${DTE}.csv

#Add totals
ltotal=$(cat DDE-PRD-Roles-${DTE}.csv | wc -l | awk '{print $0-1}')
echo "Total rows "$ltotal >> DDE-PRD-Roles-${DTE}.csv

#Email reports
mutt -s "DDE Application Roles" -a DDE-PRD-Roles-${DTE}.csv -- $SOXDL < MailHeaderDDEapp.txt
rm DDE-PRD-Roles-${DTE}.csv


:r ~/paths/



