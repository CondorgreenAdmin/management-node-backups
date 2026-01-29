if [ ! -s heading.txt ]; then
        echo "There are no deals for 30 months term" > data.txt
else
        mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers(202410, 'CBU', 30, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_$
        mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_hd_headline_approvers(202410, 'VBU', 30, 1)" --batch --raw | grep -v business_unit | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12"_$
        cr_current_block heading.txt data.txt "99" "Running"
fi

