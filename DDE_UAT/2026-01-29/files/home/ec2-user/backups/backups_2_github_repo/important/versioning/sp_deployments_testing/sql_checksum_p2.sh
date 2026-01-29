#!/bin/bash


FILES=$(ls ./rollback_scripts/)
echo $FILES

#cat rollback_scripts/testing_mic.sql | sed 's/DEFINER=`admin`@`%` \s*//g'


for file in $FILES; do
	echo "Processing: $file"
	cat rollback_scripts/$file | sed 's/DEFINER=`admin`@`%` \s*//g' | sed 's/DELIMITER ;/\nDELIMITER ;/' | sed 's/DELIMITER \/\/$/DELIMITER \/\/\n/' > db_temp_compare
	cat downloaded/$file | sed '1s/`\(.*\)`/\1/g' | sed 's/END\/\//END\n\/\//' > s3_temp_compare
	diff db_temp_compare s3_temp_compare
	echo
done

