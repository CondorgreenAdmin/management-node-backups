#!/bin/bash

############################################################################################
############################################################################################
### Call various scripts/commands and produce a daily consolidated healthcheck HTML file
############################################################################################
############################################################################################

cr_webpage_begin() {

out=$2

#INFILE to be passed
infile=$1

#HTML subject to be passed
html_subject=$(cat $infile|head -1)
html_minor=$(cat $infile | head -2|tail -1)

echo '<!DOCTYPE html>' > $out
echo '<html lang="en">' >> $out
echo '<style>' >> $out
echo 'table, th, td {' >> $out
echo '  border: 1px solid black;'>> $out
echo '  border-collapse: collapse;' >> $out
echo '}'>> $out
echo 'th, td {' >> $out
echo '   padding: 4px;' >> $out
echo '   text-align: center;' >> $out
echo '}'>> $out
echo 'th {' >> $out
echo '   text-align: left;' >> $out
echo '}'>> $out
echo '</style>' >> $out
echo '<body>' >> $out

echo '<h1>'$html_subject'</h1>' >> $out
echo '<h2>'$html_minor'</h1>' >> $out
echo '<h3>'$DTE1'</h3>' >> $out
echo '<br>' >> $out
}



cr_heading() {
   html_minor=$1
   echo '<p><b>' >> $out
   echo $html_minor >> $out
   echo '</b></p>' >> $out
}



cr_current_block() {

   num_cols=$(cat $1 | wc -w)
   head_line=$(cat $1)
   checkcol=$3
   checkval1=$4
   if [[ "x"$5 == "x" ]];then
     checkval2="dummy"
   else
     checkval2=$5
   fi


   echo '<table>' >> $out
   echo '<tr>' >> $out

   for i in $head_line
   do
     echo "<th bgcolor="lightgrey" style=\"text-align:left\"><b>"${i}"</b></th>" >> $out
   done
# echo "<th>blank</th>" >> $out
   echo '</tr>' >> $out

   while read junk
   do

     echo '<tr>' >> $out
     jcnt=1
     for jcol in $junk
     do
       if (( $jcnt == $checkcol ));then
         if [[ $checkval1 == "EVAL" ]];then
           if eval '[ $jcol ${checkval2} ]';then
             echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"lightgreen\">"nam"</td>"}' >> $out
           else
             echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"yellow\">"nam"</td>"}' >> $out
           fi
         else
           if [[ $jcol == $checkval1 || $jcol == $checkval2 ]];then
             echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"lightgreen\">"nam"</td>"}' >> $out
           else
             echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"yellow\">"nam"</td>"}' >> $out
           fi
         fi
       else
         echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td>"nam"</td>"}' >> $out
       fi
     jcnt=$(( jcnt + 1 ))
     done
     echo '</tr>' >> $out
   done<$2

   echo "</table>" >> $out
   echo '<p></p>' >> $out
   echo "</body>" >> $out
   echo '<br>' >> $out
}



cr_webpage_complete() {
echo "</html>" >> $out
}

######################
##Main section starts
######################

export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

DTE1=$(date +"%d-%B-%Y")
DTE2=$(date +"%Y-%m-%d")

attachment=$(echo "DDE_NONPROD(UAT)_healthcheck_"$DTE2".html")
out1=$$_temp_html

#start with HTML headers
echo "DDE HEALTHCHECKS" > $out1
echo "NONPROD(UAT)" >> $out1
cr_webpage_begin $out1 $attachment


#first table

cr_heading "Kubernetes status"
#first column headings
echo "EKS_Node Status" > heading.txt
./show_eks_status.sh > data.txt
##FORMAT-1: 1) pass column headings file, 2) pass the data file, 3) pass the column to check, 4) pass ok value1, 5) pass ok value2
##FORMAT-2: 1) pass column headings file, 2) pass the data file, 3) pass the column to check, 4) pass EVAL, 5) pass what to evaluate as value2
cr_current_block heading.txt data.txt "2" "running"

###move on to the next table

cr_heading "RDS Node statuses"
echo "RDS_Node Status" > heading.txt
./show_rds.sh > data.txt
cr_current_block heading.txt data.txt "2" "available" "normal"

cr_heading "K8S backups status"
echo "BackupVaultName ResourceType Status CreationDate CompletionDate BackupSize(GB) DeleteAt IsEncrypted" > heading.txt
aws backup list-recovery-points-by-backup-vault --backup-vault-name Default | egrep "BackupVaultName|ResourceType|Status|CreationDate|CompletionDate|BackupSizeInBytes|DeleteAt|IsEncrypted" | sed 's/"//g' | sed 's/,//g' | awk '{a=$2;getline;b=$2;getline;c=$2;getline;d=$2;getline;e=$2;getline;f=$2;getline;g=$2;getline;h=$2;print a,b,c,d,e,int(f/1024/1024/1024),g,h}' | head -4 > data.txt
cr_current_block heading.txt data.txt "3" "COMPLETED"

cr_heading "RDS backup status"
echo "DBClusterIdentifier SnapshotCreateTime AllocatedStorage(GB) Status EngineVersion SnapshotType PercentProgress StorageEncrypted" > heading.txt
aws rds describe-db-cluster-snapshots | egrep "DBClusterIdentifier|SnapshotCreateTime|AllocatedStorage|Status|EngineVersion|SnapshotType|PercentProgress|StorageEncrypted" | sed 's/"//g' | sed 's/,//g' | awk '{a=$2;getline;b=$2;getline;c=$2;getline;d=$2;getline;e=$2;getline;f=$2;getline;g=$2;getline;h=$2;print a,b,c,d,e,f,g,h}' | tail -4 > data.txt
cr_current_block heading.txt data.txt "7" "100"

cr_heading "K8S Filesystem status"
echo "Mount_point Percentage_used" > heading.txt
df -h | sed "s/%//g" | egrep "/dev/nvme" | awk '{printf "%-40s %-10d\n",$6,$5}' > data.txt
cr_current_block heading.txt data.txt "2" "EVAL" "-lt 75"

cr_heading "Kubernetes POD status"
echo "POD_Name Counts Status Restarts Age" > heading.txt
kubectl get pods | grep depl | awk '{printf "%-40s %-10s %-10s %-10s %-10s\n",$1,$2,$3,$4,$5}' > data.txt
cr_current_block heading.txt data.txt "3" "Running"

cr_heading "Kubernetes (Website) TLS certificate"
echo "NotBefore notAfter Days_still_valid" > heading.txt
./show_eks_nlb_tls.sh > data.txt
cr_current_block heading.txt data.txt "3" "EVAL" "-gt 60"

cr_heading "RDS (Database) TLS certificate"
echo "Instance_name CA_identifier notAfter Days_still_valid" > heading.txt
./show_rds_tls.sh > data.txt
cr_current_block heading.txt data.txt "4" "EVAL" "-gt 60"

cr_webpage_complete

###Publish report
mutt -e "set content_type=text/html" -s "DDE NONPROD(UAT) Health Checks" -a ${attachment} -- $DL < $attachment


#ls -lt | head -10
#echo
#echo
rm heading.txt data.txt sent $attachment $out1
#echo
#ls -lt | head -10


