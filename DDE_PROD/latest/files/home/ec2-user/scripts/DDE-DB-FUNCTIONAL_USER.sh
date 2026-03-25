#!/bin/bash

#Get DDE Database users
#
export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_sox_mysql_users" --batch --raw | sed 's/\t/,/g' > $$_DB_USERS

echo "userName,passwordAge,accountLocked,passwordExpired" | awk -F ',' '{printf "%-15s %-15s %-15s %-15s\n",$1,$2,$3,$4}'
cat $$_DB_USERS | egrep "SYSTEM|userName" | awk -F ',' '{printf "%-15s %-15s %-15s %-15s\n",$1,$7,$8,$9}'

rm $$_DB_USERS


