#!/bin/bash
#
#       Local account password changer
#       Version 17.10.23 
#
#	Check if date is 1st or 20th
CURR_DATE=`date +%d`
if [ $CURR_DATE -ne "05" -a $CURR_DATE -ne "25" ]
then 
	exit
fi
#
#	Functions
function CH_PASSWD() {
        CH_USER_NAME=`echo $1`
        if [ `grep -w ^$CH_USER_NAME /etc/passwd` ]
        then
                echo "$CH_USER_NAME:`tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16`" | /usr/sbin/chpasswd
        fi
}
#
REP_DATE=`date +%C%y%m-%b`
RUN_DATE=`date +%Y-%m-%d\ %H:%M`
RUN_WEEK=`date +%Y-%V`
HOST_NAME=`hostname`
PASSWD_FILE=/etc/passwd
NOCLASS_FILE=`echo '/tmp/'$HOST_NAME'_passwd_noclass.txt'`
NOCLASS_USER=0
#
>$NOCLASS_FILE
#
#       Check for issues with GECOS fields
#
grep ^root: /etc/passwd &> /dev/null      && usermod -c "Root Administration Account,SYSADM" root &>/dev/null
grep ^pamrecon: /etc/passwd &> /dev/null  && usermod -c "CyberArk,SYSADM" pamrecon  &>/dev/null
grep ^pamlogon: /etc/passwd &> /dev/null  && usermod -c "CyberArk,SYSADM" pamlogon  &>/dev/null
grep ^dna: /etc/passwd &> /dev/null       && usermod -c "CyberARK DNA Account,SYSADM" dna  &>/dev/null
grep ^hpsmh: /etc/passwd &> /dev/null     && usermod -c "HP System Homepage Owner,SYSADM" hpsmh  &>/dev/null
grep ^bin: /etc/passwd &> /dev/null       && usermod -c "bin,DEFAULT" bin   &>/dev/null
grep ^daemon: /etc/passwd &> /dev/null    && usermod -c "daemon,DEFAULT" daemon  &>/dev/null
grep ^adm: /etc/passwd &> /dev/null       && usermod -c "adm,DEFAULT" adm  &>/dev/null
grep ^lp: /etc/passwd &> /dev/null        && usermod -c "lp,DEFAULT" lp  &>/dev/null
grep ^sync: /etc/passwd &> /dev/null      && usermod -c "sync,DEFAULT" sync  &>/dev/null
grep ^shutdown: /etc/passwd &> /dev/null  && usermod -c "shutdown,DEFAULT" shutdown  &>/dev/null
grep ^halt: /etc/passwd &> /dev/null      && usermod -c "halt,DEFAULT" halt  &>/dev/null
grep ^mail: /etc/passwd &> /dev/null      && usermod -c "mail,DEFAULT" mail  &>/dev/null
grep ^uucp: /etc/passwd &> /dev/null      && usermod -c "uucp,DEFAULT" uucp  &>/dev/null
grep ^operator: /etc/passwd &> /dev/null  && usermod -c "operator,DEFAULT" operator  &>/dev/null
grep ^games: /etc/passwd &> /dev/null     && usermod -c "games,DEFAULT" games  &>/dev/null
grep ^gopher: /etc/passwd &> /dev/null    && usermod -c "gopher,DEFAULT" gopher  &>/dev/null
grep ^ftp: /etc/passwd &> /dev/null       && usermod -c "FTP User,DEFAULT" ftp  &>/dev/null
grep ^nobody: /etc/passwd &> /dev/null    && usermod -c "Nobody,DEFAULT" nobody  &>/dev/null
grep ^dbus: /etc/passwd &> /dev/null      && usermod -c "System message bus,DEFAULT" dbus  &>/dev/null
grep ^vcsa: /etc/passwd &> /dev/null      && usermod -c "virtual console memory owner,DEFAULT" vcsa  &>/dev/null
grep ^rpc: /etc/passwd &> /dev/null       && usermod -c "Rpcbind Daemon,DEFAULT" rpc  &>/dev/null
grep ^abrt: /etc/passwd &> /dev/null      && usermod -c "abrt,DEFAULT" abrt  &>/dev/null
grep ^rpcuser: /etc/passwd &> /dev/null   && usermod -c "RPC Service User,DEFAULT" rpcuser  &>/dev/null
grep ^nfsnobody: /etc/passwd &> /dev/null && usermod -c "Anonymous NFS User,DEFAULT" nfsnobody  &>/dev/null
grep ^haldaemon: /etc/passwd &> /dev/null && usermod -c "HAL daemon,DEFAULT" haldaemon  &>/dev/null
grep ^ntp: /etc/passwd &> /dev/null       && usermod -c "ntp,DEFAULT" ntp  &>/dev/null
grep ^saslauth: /etc/passwd &> /dev/null  && usermod -c "Saslauthd user,DEFAULT" saslauth  &>/dev/null
grep ^postfix: /etc/passwd &> /dev/null   && usermod -c "postfix,DEFAULT" postfix  &>/dev/null
grep ^sshd: /etc/passwd &> /dev/null      && usermod -c "Privilege-separated SSH,DEFAULT" sshd  &>/dev/null
grep ^tcpdump: /etc/passwd &> /dev/null   && usermod -c "tcpdump,DEFAULT" tcpdump  &>/dev/null
grep ^oracle: /etc/passwd &> /dev/null    && usermod -c "Oracale Account,DBA" tcpdump  &>/dev/null
grep ^grid: /etc/passwd &> /dev/null      && usermod -c "Grid Account,DBA" tcpdump  &>/dev/null
grep ^ccsadmin: /etc/passwd &> /dev/null  && usermod -c "CCS Symantec Control Compliance,SYSADM" ccsadmin  &>/dev/null
grep ^csgmon: /etc/passwd &> /dev/null    && usermod -c "Sitescope Monitoring,SYSADM" csgmon  &>/dev/null
grep ^ucmdb: /etc/passwd &> /dev/null     && usermod -c "UCMDB for Discovery,SYSADM" ucmdb  &>/dev/null
grep ^polkitd: /etc/passwd &> /dev/null   && usermod -c "User for polkitd,DEFAULT" polkitd  &>/dev/null
grep ^sssd: /etc/passwd &> /dev/null      && usermod -c "User for sssd,DEFAULT" sssd  &>/dev/null
grep ^chrony: /etc/passwd &> /dev/null    && usermod -c "User for chrony,DEFAULT" chrony  &>/dev/null
grep ^tss: /etc/passwd &> /dev/null       && usermod -c "Account used by the trousers package to sandbox the tcsd daemon,DEFAULT" tss  &>/dev/null
grep ^geoclue: /etc/passwd &> /dev/null   && usermod -c "User for geoclue,DEFAULT" geoclue  &>/dev/null
grep ^pcp: /etc/passwd &> /dev/null       && usermod -c "Performance Co-Pilot,DEFAULT" pcp  &>/dev/null
grep ^systemd-network: /etc/passwd &> /dev/null  && usermod -c "systemd Network Management,DEFAULT" systemd-network  &>/dev/null
grep ^libstoragemgmt: /etc/passwd &> /dev/null   && usermod -c "daemon account for libstoragemgmt,DEFAULT" libstoragemgmt  &>/dev/null
#
IFS=$'\n'
GECOS_USER_LIST=(`IFS='.';awk -F ":" '{print $1":" $5}' $PASSWD_FILE`)
PASS_USER_TOTAL=`wc -l $PASSWD_FILE`
#IFS='.'
	
for GECOS_USER_NAME in ${GECOS_USER_LIST[@]}
do
	IFS=$'\n'
	GECOS_STAT=0
	NOCLASS_USER=0
        USER_NAME=`echo $GECOS_USER_NAME | cut -d: -f1`
        GECOS_FIELD=`echo $GECOS_USER_NAME | cut -d: -f2`
        GECOS_CLASS=`echo $GECOS_USER_NAME | cut -d, -f2 | cut -d"," -f2 `
        case $GECOS_CLASS in
		DEFAULT)
			GECOS_STAT=0
		;;
		SYSADM)
			GECOS_STAT=0
		;;
		DBA)
			GECOS_STAT=0
		;;
		APPSUP)
			GECOS_STAT=0
		;;
		*)
		#	Account is flagged as an issue
			GECOS_STAT=0
			NOCLASS_USER=1
			#echo "GECOS="$GECOS_CLASS"---"$USER_NAME " has no classication, Please correct"
			#echo "$RUN_DATE,$HOST_NAME,$USER_NAME,$GECOS_FIELD,No_Classication"
			echo "$RUN_WEEK,$RUN_DATE,$HOST_NAME,$USER_NAME,$GECOS_FIELD,No_Classication" >> $NOCLASS_FILE
		;;
	esac
done
#
#	Password reset for default users
#       KJ_20190313 - Remove oemagent as the account has to be locked (if passwd change account is no longer locked)
#       KJ_20240215 - Remove the following account as it is managed by Cyberark now --> ccsadmin, csgmon, oracle, grid
# 		KJ_20240308 - Hashed out this section as these accounts are now being onboard and maged by CyberArk - now
#for USER_NAME in ccsadmin csgmon ucmdb oracle grid
#do
#        CH_PASSWD $USER_NAME
#done
#
#	Password reset for custom users 
if [ -f /etc/monthly_password ]
then 
	PASS_USER_LIST=(`cat /etc/monthly_password`)
	for PASS_USER_NAME in ${PASS_USER_LIST[@]}
	do
        	CH_PASSWD $PASS_USER_NAME
	done
else
	echo "No /etc/monthly_password found "
fi
#
#	Email results
#if [ $NOCLASS_USER -eq 1 -a -f /usr/bin/mutt ]
#then
#	/usr/bin/mutt -s "Passwd_Reset" -c lodewyka@psto101zatcrh.vodacom.corp < $NOCLASS_FILE
#fi
rm $NOCLASS_FILE
