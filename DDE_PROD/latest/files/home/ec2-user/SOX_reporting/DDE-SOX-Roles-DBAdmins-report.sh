#!/bin/bash

cd SOX_reporting/

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

DTE=$(date +"%Y-%m-%d")

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, blaine.simpson@vcontractor.co.za, khanya.mankosi@vcontractor.co.za, yamkela.matolengwe@condorgreen.com"
SOXDL="$DL,Jeanine.DuToit@vodacom.co.za, Atiyyah.Kajee@vodacom.co.za"

# SOXDL=$DL

#Get DDE Database users
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_sox_mysql_users" --batch --raw | sed 's/\t/,/g' > DDE-PRD-Database-Users-${DTE}.csv

#Add totals
ltotal=$(cat DDE-PRD-Database-Users-${DTE}.csv | wc -l | awk '{print $0-1}')
echo "Total rows "$ltotal >> DDE-PRD-Database-Users-${DTE}.csv

#Email reports
mutt -s "DDE Database Users" -a DDE-PRD-Database-Users-${DTE}.csv -- $SOXDL < MailHeaderDDEdb.txt

###Check for password age and email request to change if age 83 days and older. Lock account if 14 days overdue (age > 104 days)
ndbname=prd-dde.cluster-czz7nbdwrez3.af-south-1.rds.amazonaws.com
usrlist=$(cat DDE-PRD-Database-Users-${DTE}.csv | egrep -v "DEFAULT|USER" | awk -F "," '{if (($7>=83)){print $1"_"$7"_"$4}'})
for u in $usrlist
do
  nnam=$(echo $u | cut -d "_" -f 1)
  nage=$(echo $u | cut -d "_" -f 2)
  nexp=$(( 90 - $nage))
  nemail=$(echo $u | cut -d "_" -f 3)
  if [[ $nemail == "NULL" ]];then
    mailto=$DL
    cat << EOF > $$email
Good day DDE support,

The password for the functional database user '$nnam' will expire in $nexp days on the database '$ndbname'.

Please log into the '$ndbname' database and change the password promptly.

Regards

EOF

  else
    mailto=$nemail
    cat << EOF > $$email
Good day,

The password for your database user '$nnam' will expire in $nexp days and your account will be locked.

Please log into the '$ndbname' database and change your password promptly.

To update your password, please use an appropriate method for your database:

For MySQL:

Using a GUI:

Logging into the UI will ask you to change your expired password immediately before allowing login.


Use the command:

SET PASSWORD FOR 'youruser'@'%'='new_password';
Replace youruser with your actual username and new_password with your desired new password.

Your new password must contain:

At least 1 uppercase letter
At least 1 lowercase letter
At least 1 number
At least 1 special character
A total length of 16 characters

For any further assistance, please contact the DDE Support team by sending an email to dopa-dde-support@vodacom.co.za.

Kind regards,
DDE Support team
EOF

  fi

  mutt -s "DDE-PRD-Database user required password change" $mailto < $$email

done

touch $$email;rm $$email
rm DDE-PRD-Database-Users-${DTE}.csv

