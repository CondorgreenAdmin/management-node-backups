#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations

#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, raeesah.khan@vcontractor.co.za, thato.mokoena1@vcontractor.co.za"
DL="arnulf.hanauer@vcontractor.co.za"

OUT=./dde-uat-admin.cnf

	mysql --defaults-extra-file=$OUT --raw --batch -e "select * from dl_triage where is_active=1" > TTT

    mutt -e "" "set content_type=text/html" -s "Failed DDE deals" $DL < TTT

cd ~

