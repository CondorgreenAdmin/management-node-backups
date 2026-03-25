lldap=" EIT_All_OS_RH_SysAdmin BDP_VM_Prod_OS_RH_AppSup"
DTE=$(date +"%Y-%m-%d")
#output=DDE-PRD-Linux-Users-${DTE}.csv
outputLOCAL=DDE-PRD-Linux-LocalUsers-${DTE}.csv
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
SOXDL="$DL,Jeanine.DuToit@vodacom.co.za,Atiyyah.Kajee@vodacom.co.za"

#Get list of all sudo users listed in /etc/sudoers and /etc/sudoers.d/*
filelist=$(sudo ls -l /etc/sudoers.d/ | grep -v "total" | awk '{print $9}')

for i in $filelist
do
  sudo cat /etc/sudoers.d/$i | egrep -v "#|Defaults|Alias" | awk '{if (( $1"X" != "X" )){print $1}}' >> $$_tmplistA
done
sudo cat /etc/sudoers | egrep -v "#|Defaults|Alias" |        awk '{if (( $1"X" != "X" )){print $1}}' >> $$_tmplistB

cat $$_tmplistB $$_tmplistA | egrep -v "%" > $$fulluserlist
rm $$_tmplistA $$_tmplistB

#Extract local user metrics
echo "Function,user_id,user_name,last_login,password_changed,password_expires,account_expiry_date,status,ssh_direct,sudo_rights,passwd_expired,passwd_age" > $outputLOCAL

getent passwd | awk -F ":" '{print $1","$5","$7}' | sort -t, -k3,3 -r > $$system-users
cat $$system-users | grep -E '^([^,]*,){3}[^,]*$' | sort -k1,1 > $$userlistA   #Categorized users
cat $$system-users | grep -E '^([^,]*,){2}[^,]*$' | sort -k1,1 > $$userlistB   #non-categorized - we will add N/A later
lcnt=$(cat $$userlistB | wc -l)
if (( $lcnt > 0 ));then
  cat $$userlistB | awk -F "," '{print $1","$2",NOCAT,"$3","$4}' >> $$userlistA
fi

catlist=$(cat $$userlistA | awk -F "," '{print $3}' | sort -u)
userlist=$(cat $$userlistA | sort -k1,1 | awk -F "," '{print $1}')

while read whole_line
do
  lname=$(echo $whole_line | awk -F "," '{print $1","$2}')
  lcat=$(echo $whole_line | awk -F "," '{print $3}')
  xxx=$(echo $whole_line | awk -F "," '{print $1}')
  llogin=$(last $xxx | head -n -2 | head -1 | awk '{print $4,$5,$6,$7}')
  if [[ "x"$llogin == "x" ]];then
    llogin="Never logged in"
  fi

  lpasswd=$(sudo chage -l $xxx | egrep "Last password change" | sed "s/,//g" | awk '{if (( $5 == "never" )){print "never"} else {print $5,$6,$7}}')
  laccount=$(sudo chage -l $xxx | egrep "Account expires" | sed "s/,//g" | awk '{if (( $4 == "never" )){print "never"} else {print $4,$5,$6}}')
  lstatusShadow=$(sudo cat /etc/shadow | grep -w $xxx | awk -F ":" '{if (( $2 == "!!" || $2 == "*" )){print "Locked"} else {print "Active"}}')

  lstatus=$(echo $whole_line | awk -F "," '{print $4}')
  if [[ $lstatus == "/sbin/nologin" ]];then
    lstatus="Locked"
  else
    lstatus="Active"
  fi 
  
  if [[ $xxx == "root" ]];then
    ldirectssh="NO"
  else
    ldirectssh="YES"   #unless its root but how do we confirm this
  fi

  tmpsudo=$(cat $$fulluserlist | grep -w $xxx | wc -l)
  if (( $tmpsudo > 0 ));then
    lsudo="YES"
  else
    lsudo="NO"
  fi

  lpasswdexpiry=$(sudo chage -l $xxx | egrep "Password expires" | sed "s/,//g" | awk '{if (( $4 == "never" )){print "never"} else {print $4,$5,$6}}')

  if [[ $lpasswdexpiry == "never" ]];then
    lpasswdexpired="NO"
  else
    tmpage=$(echo $(date +%s)" "$(date -d "$(sudo chage -l $xxx | grep 'Password expires' | cut -d: -f2-)" +%s) | awk '{print int(($2-$1)/86400)}')
    if (( $tmpage<0 ));then
      lpasswdexpired="YES"
    else
      lpasswdexpired="NO"
    fi 
  fi
  lpasswdage=$(echo $(date +%s)" "$(date -d "$(sudo chage -l $xxx | grep 'Last password change' | cut -d: -f2-)" +%s) | awk '{print int(($1-$2)/86400)}')

  echo $lcat,$lname,$llogin,$lpasswd,$lpasswdexpiry,$laccount,$lstatusShadow,$ldirectssh,$lsudo,$lpasswdexpired,$lpasswdage >> $$outlist
done < $$userlistA
echo

cat $$outlist | sort -t, -k1,1 -r >> $outputLOCAL

#Support expiry email starts
touch $$outMSG
cat $outputLOCAL | egrep "SYSADM|NOCAT" | awk -F "," '{if (($12>83)){print "user= "$2"   age=" $12}}' > $$outMSG
if (( $(cat $$outMSG | wc -l) > 0 ));then
cat << EOF > $$outBODY
The following users are nearing or have exceeded their 90 day password age.

Please update the passwords.

EOF
   cat $$outMSG >> $$outBODY
   echo >> $$outBODY
   echo "Regards" >> $$outBODY
   echo "DDE Support team" >> $$outBODY

   mutt -s "DDE PRD Linux Local expired passwords" $DL < $$outBODY
   rm $$outBODY $$outMSG
fi
##Support check ends

#Add totals
ltotal=$(cat $outputLOCAL | wc -l | awk '{print $0-1}')
echo "Total rows "$ltotal >> $outputLOCAL

#Email attachments
mutt -s "DDE Linux Local Users" -a $outputLOCAL -- $SOXDL < MailHeaderDDELinux.txt


#cat $outputLOCAL

rm $$system-users
rm $$outlist
rm $$userlistA
rm $$userlistB
rm $$fulluserlist
rm $outputLOCAL
