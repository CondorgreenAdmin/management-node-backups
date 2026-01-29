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
echo '<hr>' >> $out
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
   echo '<hr>' >> $out
}

cr_current_block_column_compare() {
   num_cols=$(cat $1 | wc -w)
   head_line=$(cat $1)
   checkcol1=$3
   checkcol2=$4

   echo '<table>' >> $out
   echo '<tr>' >> $out
   for i in $head_line
   do
     echo "<th bgcolor="lightgrey" style=\"text-align:left\"><b>"${i}"</b></th>" >> $out
   done
   echo '</tr>' >> $out
   while read junk
   do
     echo '<tr>' >> $out
     jcnt=1

     for jcol in $junk
     do
       if (( $jcnt == $checkcol1 ));then
	 checkval=$jcol  #value of the first column
         #echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td>"nam"</td>"}' >> $out
       fi	 
       if (( $jcnt == $checkcol2 ));then
         if [ $checkval == $jcol ];then  #compare rhe two split columns
           echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"lightgreen\">"nam"</td>"}' >> $out
         else
           echo $jcol | awk '{nam=$1;gsub("#"," ",nam);print "<td bgcolor=\"yellow\">"nam"</td>"}' >> $out
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
   echo '<hr>' >> $out
}

cr_webpage_complete() {
echo "</html>" >> $out
}

######################
##Main section starts
######################

export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

#DL="michaelalex.dirks@vcontractor.co.za, arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za, arnulf.hanauer@condorgreen.com"
#DL="lukhanyo.vakele@vcontractor.co.za"
DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)

DTE1=$(date +"%d-%B-%Y")
DTE2=$(date +"%Y-%m-%d")
PREV_DATE=$(date -d 'last month' +%m_%Y)

attachment=$(echo "DDE_NONPROD(UAT)_monthly_release_checks_"$DTE2".html")
out1=$$_temp_html

#start with HTML headers
echo "DDE Application & Database Procedure versioning" > $out1
echo "NONPROD(UAT)" >> $out1
cr_webpage_begin $out1 $attachment


cr_heading "DDE Application Software Versioning"
echo "Date Image Pod_Full_Name Published_version Running_version CRQ" > heading.txt
#./show_app_versions.sh >> myfile
cat ~/versioning/scripts/software_versioning_${PREV_DATE}.txt | sort -k2,2 -k1,1n > $$_sort_data

#cr_current_block_column_compare heading.txt ${data1} "4" "5"
cr_current_block_column_compare heading.txt $$_sort_data  "4" "5"

cr_heading "DDE Database Stored Procedure & Functions Versioning"
echo "Date Object Release_Version Published_timestamp Published_Tracking_No Running_timestamp Running_Tracking_No CRQ" > heading.txt
#./show_proc_versions.sh >> myfile
cr_current_block_column_compare heading.txt ~/versioning/scripts/proc_versioning_$PREV_DATE.txt "5" "7"

cr_webpage_complete

# move month file safely before removing
filename=$(echo "DDE_NONPROD(UAT)_monthly_release_checks_"$DTE2".html")
cat $attachment > ~/versioning/scripts/monthly_release/$filename

###Publish report
mutt -e "set content_type=text/html" -s "DDE NONPROD(UAT) Monthly Release Checks" -a ${attachment} -- $DL < $attachment
#mutt -e "set content_type=text/html" -s "DDE NONPROD(UAT) Health Checks" arnulf.hanauer@vcontractor.co.za < $attachment


#ls -lt | head -10
#echo
#echo
rm heading.txt $attachment $out1 $$_sort_data
#echo
#ls -lt | head -10


