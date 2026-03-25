#!/bin/bash

logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}


export SHELL=/bin/bash

export INFORMIXDIR=/opt/IBM/Informix_Client-SDK
export PATH=/opt/IBM/Informix_Client-SDK/bin:/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin:/usr/local/instantclient_21_16:/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin
export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin
export INFORMIXSERVER=vspprim_tcp

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

cd ~/automation/dataloads/scripts

# CHANNEL HIERARCHY
./unload-epx-channel-hierarchy.sh
rc=$?

if [ $rc -eq 0 ];then
	sleep 3
	./transform-epx-channel-hierarchy.sh
	if [ $? -eq 0 ];then

		sleep 3
		./load-mysql-channel-hierarchy.sh
		if [ $? -ne 0 ];then
     			logger "ERROR LOADING: sending email"
			tail -30 logs/status.log > $$_msg
			mutt -s "DDE EPPIX source refresh has failed during LOADING - Please investigate" -- $DL < $$_msg
		else
			tail -30 logs/status.log > $$_msg
			mutt -s "DDE EPPIX source refresh succeeded" -- $DL < $$_msg	
		fi	
	else
     		logger "ERROR TRANSFORMING: sending email"
		tail -75 logs/status.log > $$_msg
		mutt -s "DDE EPPIX source refresh has failed during TRANSFORMATION - Please investigate" -- $DL < $$_msg	
	fi
else
     logger "ERROR UNLOADING: sending email"
     tail -30 logs/status.log > $$_msg
     mutt -s "DDE EPPIX source refresh has failed during UNLOAD - Please investigate" -- $DL <  $$_msg

fi	

logger ""

touch $$_msg;rm $$_msg

cd ~
