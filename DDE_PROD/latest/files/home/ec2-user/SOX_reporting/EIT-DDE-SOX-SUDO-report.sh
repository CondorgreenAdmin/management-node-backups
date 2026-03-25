#!/bin/bash

cd SOX_reporting/

#clear
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, blaine.simpson@vcontractor.co.za, khanya.mankosi@vcontractor.co.za, yamkela.matolengwe@condorgreen.com"
DLSOX="$DL, Jeanine.DuToit@vodacom.co.za, Atiyyah.Kajee@vodacom.co.za"
DTE=$(date +"%Y-%m-%d")
outputSUDO=DDE-PRD-Linux-SudoUsers-${DTE}.csv
echo "Source,Sudo User,Sudo Commands" > $outputSUDO

# DLSOX=$DL

#Get LDAP info first
#lldap="EIT_All_OS_RH_SysAdmin EIT_DDE_Prod_OS_RH_AppSup EIT_DDE_Prod_OS_RH_SUDO_Access"
lldap="EIT_All_OS_RH_SysAdmin EIT_DDE_Prod_OS_RH_AppSup"

touch sudolist.csv
rm sudolist.csv

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

  userlistLDAP=""

  for ldname in $ldap
  do
     getent group $ldname > $$ldapusers
     userlistX=$(cat $$ldapusers | awk -F ":" '{print $4}' | sed "s/,/ /g")
     userlistLDAP=$(echo $userlistLDAP" "$userlistX)
  done

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
      echo $ldap,$xxx","$ldata2 >> $outputSUDO 
    else
      echo $ldap,$xxx","$ldata1 $ldata2 >> $outputSUDO
    fi

  done
done
ltotal=$(cat $outputSUDO | wc -l | awk '{print $0-1}')
echo "Total rows "$ltotal >> $outputSUDO

#Email attachments
mutt -s "DDE Linux Sudo Users" -a $outputSUDO -- $DLSOX < MailHeaderDDELinuxSudo.txt
#mutt -s "TEST DDE Linux Sudo Users" -a $outputSUDO -- $DL < MailHeaderDDELinuxSudo.txt

rm $$ldapusers userlistA userlistB
rm $outputSUDO
