DTE=$(date +"%Y-%m-%d")
NAM=DDE-PRD-DB_versioning-${DTE}.csv

#Get DDE application users
mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_sox_versioning" --batch --raw | sed 's/\t/,/g' > $NAM

#Add totals
ltotal=$(cat $NAM | wc -l | awk '{print $0-1}')
if (( $ltotal>0 ));then
  echo "Total rows "$ltotal >> $NAM
fi

#Email reports
mutt -s "DDE Application DB versioning" -a $NAM -- "arnulf.hanauer@vcontractor.co.za,sean.muller@condorgreen.com " < MailHeaderDDE_DBversions.txt

rm $NAM

