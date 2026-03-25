#clear
touch sudolist.csv
rm sudolist.csv
DTE=$(date +"%Y-%m-%d")
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
SOXDL="$DL, Jeanine.DuToit@vodacom.co.za, Atiyyah.Kajee@vodacom.co.za"

outputSUDO=DDE-PRD-Linux-SudoUsers-${DTE}.csv
echo "Source,Sudo User,Sudo Commands" > $outputSUDO

#Get LDAP info first
lldap=" EIT_All_OS_RH_SysAdmin BDP_VM_Prod_OS_RH_AppSup"
userlistLDAP=""

for ldname in $lldap
do
   getent group $ldname > $$ldapusers
   userlistX=$(cat $$ldapusers | awk -F ":" '{print $4}' | sed "s/,/ /g")
   userlistLDAP=$(echo $userlistLDAP" "$userlistX)
done

#Get list of all sudo users listed in /etc/sudoers and /etc/sudoers.d/*
filelist=$(sudo ls -l /etc/sudoers.d/ | grep -v "total" | awk '{print $9}')
touch userlistA
rm userlistA
touch userlistB
rm userlistB

for i in $filelist
do
  sudo cat /etc/sudoers.d/$i | egrep -v "#|Defaults|Alias" | awk '{if (( $1"X" != "X" )){print $1}}' >> userlistA
done
sudo cat /etc/sudoers | egrep -v "#|Defaults|Alias" |        awk '{if (( $1"X" != "X" )){print $1}}' >> userlistB

fulluserlist=$(cat userlistB userlistA | egrep -v "%")

#Now troll through each user and check
for xxx in $fulluserlist
do
  ldataX=""
  ldata2=""
  ldata1=$(sudo cat /etc/sudoers | egrep -v "#" | egrep $xxx | awk '{ for(i=2; i<=NF; i++) printf "%s ", $i}' | sed "s/,/ /g") 
  for lfile in $filelist
  do
    ldataX=$(sudo cat /etc/sudoers.d/$lfile | egrep -v "#" | egrep $xxx | awk '{ for(i=2; i<=NF; i++) printf "%s ", $i}' | sed "s/*/ /g" | sed "s/,/ /g") 
    if [[ "x"$ldataX != "x" ]];then
      ldata2=$(echo $ldata2" "$ldataX)
    fi
  done
  if [[ "x"$ldata1 == "x" ]];then
    echo "Local",$xxx","$ldata2 >> $outputSUDO 
  else
    echo "Local",$xxx","$ldata1 $ldata2 >> $outputSUDO
  fi
done

for ldap in $lldap 
do
  ldapgrpname=$(echo $ldap | awk '{print "%"$0}')
  for xxx in $userlistLDAP
  do
    ldataX=""
    ldata2=""
    ldata1=$(sudo cat /etc/sudoers | egrep -v "#" | egrep $ldapgrpname | awk '{ for(i=2; i<=NF; i++) printf "%s ", $i}' | sed "s/,/ /g") 
    for lfile in $filelist
    do
      ldataX=$(sudo cat /etc/sudoers.d/$lfile | egrep -v "#" | egrep $ldapgrpname | awk '{ for(i=2; i<=NF; i++) printf "%s ", $i}' | sed "s/*/ /g" | sed "s/,/ /g") 
      if [[ "x"$ldataX != "x" ]];then
        ldata2=$(echo $ldata2" "$ldataX)
      fi
    done
    #they can all be blank and we use the ldapgroupname
    if [[ "x"$ldata1 == "x" ]];then
      echo "LDAP",$xxx","$ldata2 >> $outputSUDO 
    else
      echo "LDAP",$xxx","$ldata1 $ldata2 >> $outputSUDO
    fi
  done
done
ltotal=$(cat $outputSUDO | wc -l | awk '{print $0-1}')
echo "Total rows "$ltotal >> $outputSUDO

#Email attachments
mutt -s "DDE Linux Sudo Users" -a $outputSUDO -- $SOXDL < MailHeaderDDELinuxSudo.txt
#mutt -s "DDE Linux Sudo Users" -a $outputSUDO -- "arnulf.hanauer@vcontractor.co.za" < MailHeaderDDELinuxSudo.txt

rm $outputSUDO
rm userlistA userlistB

