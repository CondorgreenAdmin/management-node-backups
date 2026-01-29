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

#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
#DL="lukhanyo.vakele@vcontractor.co.za, lukhanyo.vakele@condogreen.com"
DL="thato.mokoena1@vcontractor.co.za, thato.mokoena@condorgreen.com"
#DL="arnulf.hanauer@vcontractor.co.za"

DTE1=$(date +"%d-%B-%Y")
DTE2=$(date +"%Y-%m-%d")
attachment=$(echo "LUKHANYO_"$DTE2".html")
out1=$$_temp_html
mail_subject="Lukhanyo"
cycle_id=$(mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "SELECT MAX(DISTINCT cycle_id) FROM dsh_headlines" --batch --raw | grep -v MAX)

#start with HTML headers
echo "DDE DEALS REPORT" > $out1
echo "NONPROD(UAT)" >> $out1
echo "Cycle ID: $cycle_id" >> $out1
cr_webpage_begin $out1 $attachment



cr_heading "Count of auto approved deals"
echo "headline_deals_count term tariff_type eff_treshhold is_auto_approved business_unit" > heading.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 24, 1, 'V')" --batch --raw | grep -v term | awk '{if ($1 != 0) {print $0}}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 24, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 30, 1, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 30, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 36, 1, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 36, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 24, 1, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 24, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 30, 1, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 30, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 36, 1, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 36, 1, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Count of not auto approved deals"
echo "headline_deals_count term tariff_type is_auto_approved business_unit" > heading.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 24, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 24, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 30, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 30, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 36, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'CBU', 36, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 24, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 24, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 30, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 30, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 36, 0, 'V')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_deals_count($cycle_id, 'VBU', 36, 0, 'D')" --batch --raw | grep -v term| awk '{if ($1 != 0) {print $0}}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Number of deals per approval level"
#echo "ApprovalLevelCount ApprocalLevelRequired BusinessUnit" > heading.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, NULL ,1)" --batch --raw | head -1 > heading.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'CBU', 1)" --batch --raw | grep -v business_unit > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'CBU', 2)" --batch --raw | grep -v business_unit >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'CBU', 3)" --batch --raw | grep -v business_unit >> data.txt
#mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'VBU', 0)" --batch --raw | grep -v business_unit >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'VBU', 1)" --batch --raw | grep -v business_unit >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'VBU', 2)" --batch --raw | grep -v business_unit >> data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approval_level_count($cycle_id, 'VBU', 3)" --batch --raw | grep -v business_unit >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Who approved level 1 deals for 24 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 24, 1)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 24, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 24, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Who approved level 1 deals for 30 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 30, 1)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 30, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 30, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Who approved level 1 deals for 36 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 36, 1)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 36, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 36, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"


cr_heading "Who approved level 2 deals for 24 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 24, 2)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 24, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 24, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Who approved level 2 deals for 30 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 30, 2)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 30, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 30, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"
  
cr_heading "Who approved level 2 deals for 36 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 36, 2)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 36, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 36, 2)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"


cr_heading "Who approved level 3 deals for 24 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 24, 3)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 24, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 24, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_heading "Who approved level 3 deals for 30 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 30, 3)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 30, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 30, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"
  
cr_heading "Who approved level 3 deals for 36 months term"
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, NULL, 36, 3)" --batch --raw | head -1 > heading.txt 
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'CBU', 36, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' > data.txt
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers($cycle_id, 'VBU', 36, 3)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_"$13}' >> data.txt
cr_current_block heading.txt data.txt "99" "Running"

cr_webpage_complete


###Publish report
#mutt -e "set content_type=text/html" -s "DDE NONPROD(UAT) Health Checks" -a ${attachment} -- $DL < $attachment
mutt -e "set content_type=text/html" -s $mail_subject  -a ${attachment} -- $DL < $attachment

#ls -lt | head -10
#echo
#echo
rm heading.txt data.txt sent $attachment $out1
#echo
#ls -lt | head -10


