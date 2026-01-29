#!/bin/bash

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE './cleaned_vpk.csv' INTO TABLE src_epx_packages_ahh FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1
