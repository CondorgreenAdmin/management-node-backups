#!/bin/bash
#
# This script uploads data to a DB on psto101zatcrh
# - Local account status and password ages
# 
#
# 1. Local account password details
#	RUN_WEEK		Query_Run_Week,		- Done
#	RUN_DATE		Query_Run_Date,		- Done
#	ORG      	 	Org,      		- Done
#	HOST_NAME		Host_Name,		- Done
#	USER_NAME		User_Name,		- Done
#	LOGIN_ACC		Login_Account,		- Done
#	LAST_LOGIN		Last_Login,		- Done
#	PASSWORD_CHANGE	Passwd_Last_Ch,			- Done
#	PASSWORD_CRYPT		Passwd_Encrypt,		- Done
#	PASSWORD_EXPIRE	Passwd_Expire, 			- Done
#	PASSWORD_AGE		Passwd_Age,		- Done
#	PASSWORD_OLD90		Passwd_Old90,		- Done
#	APP_USER		App_User,		- Done
#	REAL_USER		Real_User		- Done
#	USER_GECOS		User_Gecos,		- Done
#	USER_SHELL		User_Shell,		- Done
#	USER_UID		User_Uid,		- Done
#	USER_GID		User_Gid		- Done
#	Run_Week,Query_Run_Date,Org,Host_Name,User_Name,Login_Account,Last_Login,Passwd_Last_Ch,Passwd_Encrypt,Passwd_Expire,Passwd_Age,Passwd_Old90,App_User,
#	Real_User,User_Gecos,User_Shell,User_Uid,User_Gid
#
HOST_NAME=`hostname`
ORG=NMG
REP_DATE=`date +%Y-%m-%d`
RUN_DATE=`date +%Y-%m-%d\ %H:%M`
RUN_WEEK=`date +%Y-%W`
REP_DIR=/tmp
REP_PID=`echo $$`
REP_DIR=/tmp
REP_PID=`echo $$`
UPLOAD_FILE1=`echo $REP_DIR"/"$HOST_NAME"_Acc_Info.txt"`
> $UPLOAD_FILE1
echo "Run_Week,Query_Run_Date,Org,Host_Name,User_Name,Login_Account,Last_Login,Passwd_Last_Ch,Passwd_Encrypt,Passwd_Expire,Passwd_Age,Passwd_Old90,App_User,Real_User,User_Gecos,User_Shell,User_Uid,User_Gid" >> $UPLOAD_FILE1

LOCAL_USER=(`cat /etc/passwd | grep -E -v DEFAULT | cut -d: -f1`)
LOCAL_USER=(`cat /etc/passwd | cut -d: -f1`)
EPOCH_NOW=`expr $(date +%s) / 86400`
SYST_MINAGE=$(grep ^PASS_MIN_DAYS /etc/login.defs | awk '{print $2}')
SYST_MAXAGE=$(grep ^PASS_MAX_DAYS /etc/login.defs | awk '{print $2}')
#
for L_USER in ${LOCAL_USER[@]}
do
	USER_NAME=`echo $L_USER`
	LOGIN_ACC='YES'
	[[ `grep ^$L_USER /etc/passwd | cut -d: -f7 | grep -E nologin\|sync\|halt\|shutdown` ]] && LOGIN_ACC='NO'
	LAST_LOGIN=`lslogins --output LAST-LOGIN --time-format iso --noheadings -l $USER_NAME | grep '^Last logi'| tr -d '[:space:]' | sed 's/Lastlogin://g'`
	LAST_LOGIN="2018-01-01"
	PASSWORD_CRYPT="No_Crypt"
        passwd -S $L_USER | grep crypt &>/dev/null
        if [ $? -eq 0 ]
	then
		PASSWORD_CRYPT=`passwd -S $L_USER | grep crypt | awk -F"(" '{print $2}' | awk -F',' '{print $2}' | awk -F" " '{print $1}'`
	fi
	USER_GECOS=`grep ^$L_USER: /etc/passwd | cut -d: -f5 | tr '[:space:]' '_' | sed 's/,/;/g' | sed 's/_$//g'`
	USER_SHELL=`grep ^$L_USER: /etc/passwd | cut -d: -f7` 
	USER_UID=`id -u $L_USER `
	USER_GID=`id -g $L_USER `
	PASSWORD_LAST_CHN=$(grep ^$L_USER: /etc/shadow | cut -d: -f3)
	PASSWORD_CHANGED=$(date +%Y-%m-%d -d "1970-01-01 + $PASSWORD_LAST_CHN  days")
	PASSWORD_AGE=`expr $EPOCH_NOW - $PASSWORD_LAST_CHN`
	PASSWORD_OLD90='NO'
	[[ $PASSWORD_AGE -ge 90 ]] && PASSWORD_OLD90='YES'
	PASSWORD_MINAGE=`grep ^$L_USER /etc/shadow | cut -d: -f4`
	PASSWORD_MAXAGE=`grep "^$L_USER\:" /etc/shadow | cut -d: -f5`
	#echo -e "MaxAge = $PASSWORD_MAXAGE \c"
	PASSWORD_EXPIRE=`date +%Y-%m-%d -d "$PASSWORD_CHANGED + $PASSWORD_MAXAGE days" `
	PASSWORD_NEVER=`chage -l $L_USER | grep ^Password\ expires | awk -F: '{print $2}' | tr -d '[:space:]'`
	[ $PASSWORD_NEVER = 'never' ] && PASSWORD_EXPIRE='1969-12-31'
	PASSWORD_STATUS=$(passwd -S $L_USER | awk '{print $2}')
	APP_USER='NO'
	[[ `grep ^$L_USER /etc/passwd | cut -d: -f5 | grep APPSUP` ]] && APP_USER='YES'
	REAL_USER='YES'
	[[ `grep ^$L_USER /etc/passwd | cut -d: -f7 | grep -E nologin\|sync\|halt\|shutdown` ]] && REAL_USER='NO'
	echo -e "$L_USER $EPOCH_NOW $PASSWORD_LAST_CHN $PASSWORD_AGE"
	echo -e "$RUN_WEEK,$RUN_DATE,$ORG,$HOST_NAME,$USER_NAME,$LOGIN_ACC,$LAST_LOGIN,$PASSWORD_CHANGED,$PASSWORD_CRYPT,$PASSWORD_EXPIRE,$PASSWORD_AGE,$PASSWORD_OLD90,$APP_USER,$REAL_USER,$USER_GECOS,$USER_SHELL,$USER_UID,$USER_GID" >> $UPLOAD_FILE1
done
#
CURL_PROG=`which curl `
if [[ -f $CURL_PROG ]]
then
	UPLOAD_TAB1='MTH_Local_Password'
	curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE1 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
fi
#MTH_Local_Password
rm -fv $UPLOAD_FILE1
