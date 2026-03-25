#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/vb_templates

#CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"
CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"


mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch < get_list.sql > drop_list.txt

sleep 3

touch todo
rm todo

while read junk
do
	echo mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 --batch -e \'drop table $junk\' >> todo
done<drop_list.txt

