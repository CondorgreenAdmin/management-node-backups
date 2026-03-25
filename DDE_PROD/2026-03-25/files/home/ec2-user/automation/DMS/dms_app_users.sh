#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/DMS

CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"

DTE=$(date +"%Y-%m-%d-%H-%M-%S")
OUT_CSV="dde_$DTE.csv"
OUT_XLS="dde_$DTE.xlsx"
RES_CSV="resources_$DTE.csv"
RES_XLS="resources_$DTE.xlsx"

touch $OUT_CSV $OUT_XLS $OUT_RES
rm $OUT_CSV $OUT_XLS $OUT_RES


mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./dde_user_login.sql | sed 's/\t/|/g' > $OUT_CSV

mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  < ./dde_user_details.sql | grep -v "first_name" | sort -u -k1,1 | sed 's/\t/|/g' > $$TEMP


##deprecated mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch < ./dde_roles.sql | grep -v "role_description" | sed 's/\t/|/g' > $$TEMP

#python3 csv2xlsx.py $OUT_CSV $OUT_XLS

cat << EOF > $$outMSG

Hi DDE support,

The following data was sent to the Vodacom DMS (Dormancy Management System).

dde application users

Kind regards
DDE Operations

EOF


###Build the resources file for upload
#echo "resource dn|entitlement value" > $RES_CSV

#ROLES=$(cat $$TEMP)      ###Roles by code deprecated - need to send this file once only or when it changes
#for ITM in $ROLES      ###ROLES deprecated, we send all possible options just once
#do
#   echo "cn=DOPA_DDE_PROD,cn=ResourceDefs,cn=RoleConfig,cn=AppConfig,cn=User Application,cn=VodacomIAMDriverSet2,ou=South,ou=Services,o=IAM|\IAM-TREE\IAM\Groups\RemoteGroups\ARM\DOPA\DOPA_DDE_PROD_$ITM" >> $RES_CSV
#done

#echo "DEBUG STARTS:##########################################################\n"
#cat $OUT_CSV
#echo
cat $OUT_CSV | sed 's/|/,/g' | sed 's/NULL//g' > ttt
cp ttt $OUT_CSV
#cat $OUT_CSV
#echo "DEBUG ENDS:############################################################\n"
#echo

#python3 csv2xlsx.py $RES_CSV $RES_XLS

###Email info to support
#DL="arnulf.hanauer@vcontractor.co.za,yusuf.pinn@vcontractor.co.za,olwethu.ketwa@vcontractor.co.za,lukhanyo.vakele@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za"
DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)


###mutt -s "DDE(Production) DMS report" -a $OUT_XLS -a $RES_XLS -- $DL < $$outMSG
#mutt -s "DDE(Production) DMS report" -a $OUT_XLS -- $DL < $$outMSG
mutt -s "DDE(Production) DMS report" -a $OUT_CSV -- $DL < $$outMSG

###Upload the documentation
#user: svc_dde
#pass: 0913Smile&@

#remmoved RESOURCES file because of Kenneth request
###curl --cacert /home/ec2-user/automation/DMS/dms2.pem --request POST --url https://dms.vodacom.corp:8443/dms/uploadfile --header 'Content-Type: multipart/form-data' --header 'Authorization:Basic c3ZjX2RkZTowOTEzU21pbGUmQA==' --form "file=@/home/ec2-user/automation/DMS/$RES_XLS"
#

#converted user file back to CSV because DMS was not picking up data##curl --cacert /home/ec2-user/automation/DMS/dms2.pem --request POST --url https://dms.vodacom.corp:8443/dms/uploadfile --header 'Content-Type: multipart/form-data' --header 'Authorization:Basic c3ZjX2RkZTowOTEzU21pbGUmQA==' --form "file=@/home/ec2-user/automation/DMS/$OUT_XLS"

##Send files vi aPOST method to DMS
curl --cacert /home/ec2-user/automation/DMS/dms2.pem --request POST --url https://dms.vodacom.corp:8443/dms/uploadfile --header 'Content-Type: multipart/form-data' --header 'Authorization:Basic c3ZjX2RkZTowOTEzU21pbGUmQA==' --form "file=@/home/ec2-user/automation/DMS/$OUT_CSV"

###Notify users of dormancy deletion
while read user
do
	LAST_DTE=$(echo $user | awk -F "|" '{print $6'})
        DTE=$(date +"%Y-%m-%d-%H-%M-%S")
	EMAIL=$(echo $user | awk -F "|" '{print $4'})
   #EMAIL=yusuf.pinn@vcontractor.co.za
	NAM=$(echo $user | awk -F "|" '{print $2" "$3'})
	USERID=$(echo $user | awk -F "|" '{print $1'})
	TIME_THEN=$(date -d "$LAST_DTE" +"%s")
	TIME_NOW=$(date +"%s")
	AGE=$(echo $(( 30-((TIME_NOW - TIME_THEN)/86400) )) | awk '{print $0}')
   #echo "$user $AGE"	
	if (( $AGE <= 10 ));then
		FULLDL="$EMAIL,$DL"
		case $AGE in
		   10|3|2|1)
		      echo "" > $$outMSG
		      echo "Good day, $NAM" >>$$outMSG
                      cat << EOF >> $$outMSG


Vodacom Dormancy policies requires you to log into the DDE application within 30 days of last login. 

According to our records, you have $AGE days left before your account becomes dormant and will be removed from ARMS/Whitepages.

If you need to retain your account, please log in to the DDE application within the next $AGE days.

URL: https://dde.vodacom.co.za

Kind regards
DDE Operations support

EOF
                     #mutt -s "DDE(Production) User dormancy notification" -- $EMAIL < $$outMSG
		     mutt -s "DDE(Production) User dormancy (countdown) notification" -- $FULLDL < $$outMSG
		     echo "$DTE : User $EMAIL was notified of $AGE remaining days" >> history/dormancy.log
		   ;;
		   0|-1|-2|-3|-4|-5|-6|-7|-8|-9)
		      echo "" > $$outMSG
		      echo "Good day, $NAM" >>$$outMSG
                      cat << EOF >> $$outMSG


Vodacom Dormancy policies requires you to log into the DDE application within 30 days of last login. 


You have not logged into the DDE application within 30 days and your account is deemed dormant. Your DDE account will now be removed from ARMS/Whitepages.


Should you need to access the DDE application, please apply for the necessary DDE ARMS/Whitepages resource(s).


Kind regards
DDE Operations support

EOF
                     mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch  -e "update usr_users set is_deleted=1 where email=\"$EMAIL\""  
                     mutt -s "DDE(Production) User dormancy notification" -- $EMAIL < $$outMSG
                     mutt -s "DDE(Production) User dormancy notification: $EMAIL" -- $DL < $$outMSG
		     echo "$DTE : User $EMAIL was notified of account deletion. DDE support also notified ($DL)" >> history/dormancy.log
		   ;;
		esac
	fi

done<$$TEMP

#mv *.xlsx history/
mv *.csv history/

###Manage history files
cd history
#ls -lt *.xlsx *.csv | awk '{print $9}' | sort -nr -k1,1 > $$CLEANUP
ls -lt *.csv | awk '{print $9}' > $$CLEANUP
MAXCNT=60
TOT=$(cat $$CLEANUP | wc -l)
CNT=$(( TOT - MAXCNT ))
if (( $CNT > 0 ));then
   TODEL=$(cat $$CLEANUP | tail -$CNT)
fi   
for ITM in $TODEL
do
   rm $ITM
done
rm $$CLEANUP
cd ..

rm $$TEMP $$outMSG ttt

