#!/bin/bash
#
# This script uploads data to a DB on psto101zatcrh
# The data is use in the monthly reports
#
export http_proxy=""
export FTP_PROXY=""
export ftp_proxy=""
export no_proxy=""
export HTTP_PROXY=""
# 
HOST_NAME=`hostname`
REP_DATE=`date +%Y-%m-%d`
RUN_DATE=`date +%Y-%m-%d\ %H:%M`
RUN_WEEK=`date +%Y-%W`
REP_DIR=/tmp
REP_PID=`echo $$`
REP_DIR=/tmp
REP_PID=`echo $$`
#===================================================================================================================================================
# 1. Local account password details
# RUN_WEEK=Query_Run_Week, RUN_DATE=Query_Run_Date, ORG=Org, HOST_NAME=Host_Name, USER_NAME=User_Name, - Done
# LOGIN_ACC=Login_Account, LAST_LOGIN=Last_Login, PASSWORD_CHANGE=Passwd_Last_Ch, PASSWORD_CRYPT=Passwd_Encrypt, 
# PASSWORD_EXPIRE=Passwd_Expire, PASSWORD_AGE=Passwd_Age, PASSWORD_OLD90=Passwd_Old90, APP_USER=App_User,
# REAL_USER=Real_User, USER_GECOS=User_Gecos, USER_SHELL=User_Shell, USER_UID=User_Uid, USER_GID=User_Gid 
#
# Run_Week,Query_Run_Date,Org,Host_Name,User_Name,Login_Account,Last_Login,Passwd_Last_Ch,Passwd_Encrypt,Passwd_Expire,Passwd_Age,Passwd_Old90,App_User,
# Real_User,User_Gecos,User_Shell,User_Uid,User_Gid
#
# Inserts into TABLE "MTH_Local_Account" in mysql DB on psto101zatcrh
#
HOST_NAME=`hostname`
ORG=VOC
REP_DATE=`date +%Y-%m-%d`
RUN_DATE=`date +%Y-%m-%d\ %H:%M`
RUN_WEEK=`date +%Y-%W`
REP_DIR=/tmp
REP_PID=`echo $$`
REP_DIR=/tmp
REP_PID=`echo $$`
UPLOAD_FILE1=`echo $REP_DIR"/"$HOST_NAME"_Acc_Info.txt"`
> $UPLOAD_FILE1
echo "Run_Week,Query_Run_Date,Org,Host_Name,User_Name,Login_Account,Last_Login,Passwd_Last_Ch,Passwd_Encrypt,Passwd_Expire,Passwd_Age,Passwd_Old90,App_User,Real_User,User_Gecos ,User_Shell,User_Uid,User_Gid" >> $UPLOAD_FILE1

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
 PASSWORD_CHANGED=$(date +%Y-%m-%d -d "1970-01-01 + $PASSWORD_LAST_CHN days")
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
 echo -e "$RUN_WEEK,$RUN_DATE,$ORG,$HOST_NAME,$USER_NAME,$LOGIN_ACC,$LAST_LOGIN,$PASSWORD_CHANGED,$PASSWORD_CRYPT,$PASSWORD_EXPIRE,$PASSWORD_AGE,$PASSWORD_OLD90,$APP_USE R,$REAL_USER,$USER_GECOS,$USER_SHELL,$USER_UID,$USER_GID" >> $UPLOAD_FILE1
done
#
CURL_PROG=`which curl `
if [[ -f $CURL_PROG ]]
then
 UPLOAD_TAB1='MTH_Local_Password'
 curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE1 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
fi
rm -fv $UPLOAD_FILE1
#===================================================================================================================================================
#
# 2. Local /etc/resolv.conf details
#       Run_Week Run_Date Host_Name Resolv_Type Resolv_Content
#
# Inserts into TABLE "MTH_Resolv_conf" in mysql DB on psto101zatcrh
#
UPLOAD_FILE2=`echo $REP_DIR"/"$HOST_NAME"_etc_Resolv_Info.txt"`
> $UPLOAD_FILE2
echo "Run_Week,Run_Date,Host_Name,Line_Type,Line_Content" >> $UPLOAD_FILE2
IFS=$'\n'     # new field separator, the end of line
LOCAL_RESOLV=(`cat /etc/resolv.conf | grep -v ^#`)
#
for L_RESOLV in ${LOCAL_RESOLV[@]}
do
        #echo $L_RESOLV
        RESOLV_TYPE=`echo $L_RESOLV | awk {'print $1'}`
        RESOLV_CONTENT=`echo $L_RESOLV | awk '{$1=""; print $0}' | sed 's/^\ //g'`
        echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$RESOLV_TYPE,$RESOLV_CONTENT" >> $UPLOAD_FILE2
done
#
IFS=' '     # new field separator, the end of line
CURL_PROG=`which curl `
if [[ -f $CURL_PROG ]]
then
        curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE2 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
fi
#
rm -fv $UPLOAD_FILE2
#===================================================================================================================================================
#
# 3. Local /etc/ntp.conf details
#       Run_Week Run_Date Host_Name NTP_Type NTP_Content
#
# Inserts into TABLE "MTH_NTP_conf" in mysql DB on psto101zatcrh
#
UPLOAD_FILE3=`echo $REP_DIR"/"$HOST_NAME"_etc_NTP_Info.txt"`
> $UPLOAD_FILE3
echo "Run_Week,Run_Date,Host_Name,Line_Type,Line_Content" >> $UPLOAD_FILE3
IFS=$'\n'     # new field separator, the end of line
LOCAL_NTP=(`cat /etc/ntp.conf  | grep -v ^# | grep ^server  | grep -v 127\.127`)
#
for L_NTP in ${LOCAL_NTP[@]}
do
        #echo $L_NTP
        NTP_TYPE=`echo $L_NTP | awk {'print $1'}`
        NTP_CONTENT=`echo $L_NTP | awk '{$1=""; print $0}' | sed 's/^\ //g'`
        echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$NTP_TYPE,$NTP_CONTENT" >> $UPLOAD_FILE3
done
#
IFS=' '     # new field separator, the end of line
CURL_PROG=`which curl `
if [[ -f $CURL_PROG ]]
then
        curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE3 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
fi
#
rm -fv $UPLOAD_FILE3
#===================================================================================================================================================
#
# 4. Local /etc/sssd/sssd.conf details
#       Run_Week Run_Date Host_Name SSSD_Type SSSD_Content
#
# Inserts into TABLE "MTH_SSSD_conf" in mysql DB on psto101zatcrh
#
UPLOAD_FILE4=`echo $REP_DIR"/"$HOST_NAME"_etc_SSSD_Info.txt"`
> $UPLOAD_FILE4
echo "Run_Week,Run_Date,Host_Name,Line_Type,Line_Content" >> $UPLOAD_FILE4
LOCAL_SSSD=(`grep simple_allow_groups /etc/sssd/sssd.conf | awk -F= '{print $2}' | sed 's/EIT_All_OS_RH_SysAdmin//g; s/\,//g'`)
COUNT_SSSD=$(grep simple_allow_groups /etc/sssd/sssd.conf | awk -F= '{print $2}' | sed 's/EIT_All_OS_RH_SysAdmin//g; s/\,//g' | wc -w )
#
if [[ $COUNT_SSSD -gt 0 ]]
then
        for L_SSSD in ${LOCAL_SSSD[@]}
        do
                echo $L_NTP
                SSSD_TYPE="Simple_Allow"
                SSSD_CONTENT=`echo $L_SSSD`
                echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$SSSD_TYPE,$SSSD_CONTENT" >> $UPLOAD_FILE4
        done
else
        SSSD_TYPE="No EDIR Groups"
        echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$SSSD_TYPE,$SSSD_CONTENT" >> $UPLOAD_FILE4
fi
#
IFS=' '     # new field separator, the end of line
CURL_PROG=`which curl `
if [[ -f $CURL_PROG ]]
then
        curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE4 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
fi
#
rm -fv $UPLOAD_FILE4
#===================================================================================================================================================
#
#	Move to a weekly report
#
# 5. Local uptime and RHEL release details
#       Run_Week Run_Date Host_Name Uptime RH_Release
#
# Inserts into TABLE "MTH_Uptime_conf" in mysql DB on psto101zatcrh
#
#UPLOAD_FILE5=`echo $REP_DIR"/"$HOST_NAME"_UpTime_Info.txt"`
#> $UPLOAD_FILE5
#echo "Run_Week,Run_Date,Host_Name,Uptime,RH_Release" >> $UPLOAD_FILE5
##
#uptime | grep days &> /dev/null
#if [ $? -ne 0 ]
#then
        #SERV_UPTIME="1"
#else
        #SERV_UPTIME=`uptime | grep days | awk '{print $3}'`
#fi
#SERV_RELEASE=`cat /etc/redhat-release`
#echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$SERV_UPTIME,$SERV_RELEASE" >> $UPLOAD_FILE5
##
#IFS=' '     # new field separator, the end of line
#CURL_PROG=`which curl `
#if [[ -f $CURL_PROG ]]
#then
        #curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE5 http://psto101zatcrh.vodacom.corp/upload_cgi/upload_mth_report.php
#fi
##
#rm -fv $UPLOAD_FILE5
#===================================================================================================================================================
