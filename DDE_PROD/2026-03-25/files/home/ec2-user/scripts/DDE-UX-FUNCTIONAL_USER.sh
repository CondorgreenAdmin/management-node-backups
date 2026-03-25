#!/bin/bash

outputLOCAL=$$_TMP_USERLIST

#Extract local user metrics
echo "userName,passwordAge,accountLocked,passwordExpired" > $outputLOCAL

getent passwd | awk -F ":" '{print $1","$5","$7}' | sort -t, -k3,3 -r > $$system-users
cat $$system-users | grep -E '^([^,]*,){3}[^,]*$' | sort -k1,1 > $$userlistA   #Categorized users
cat $$system-users | grep -E '^([^,]*,){2}[^,]*$' | sort -k1,1 > $$userlistB   #non-categorized - we will add N/A later
lcnt=$(cat $$userlistB | wc -l)
if (( $lcnt > 0 ));then
  cat $$userlistB | awk -F "," '{print $1","$2",NOCAT,"$3","$4}' >> $$userlistA
fi

cat $$userlistA | egrep "ec2-user" > $$userlistB   #Use as master list

while read whole_line
do
  luser=$(echo $whole_line | awk -F "," '{print $1}')
  lstatusShadow=$(sudo cat /etc/shadow | grep -w $luser | awk -F ":" '{if (( $2 == "!!" || $2 == "*" )){print "Locked"} else {print "Active"}}')
  
  lpasswdexpiry=$(sudo chage -l $luser | egrep "Password expires" | sed "s/,//g" | awk '{if (( $4 == "never" )){print "never"} else {print $4,$5,$6}}')
  if [[ $lpasswdexpiry == "never" ]];then
    lpasswdexpired="NO"
  else
    tmpage=$(echo $(date +%s)" "$(date -d "$(sudo chage -l $luser | grep 'Password expires' | cut -d: -f2-)" +%s) | awk '{print int(($2-$1)/86400)}')
    if (( $tmpage<0 ));then
      lpasswdexpired="YES"
    else
      lpasswdexpired="NO"
    fi 
  fi
  lpasswdage=$(echo $(date +%s)" "$(date -d "$(sudo chage -l $luser | grep 'Last password change' | cut -d: -f2-)" +%s) | awk '{print int(($1-$2)/86400)}')

  echo $luser,$lpasswdage,$lstatusShadow,$lpasswdexpired >> $$outlist
done < $$userlistB

cat $$outlist | sort -t, -k1,1 -r >> $outputLOCAL

cat $outputLOCAL | awk -F ',' '{printf "%-15s %-15s %-15s %-15s\n",$1,$2,$3,$4}'

rm $$system-users
rm $$outlist
rm $$userlistA
rm $$userlistB
rm $outputLOCAL
