#!/bin/bash

SYS=$1

if [[ "A"$SYS == "A" ]];then
	echo "ERROR: You need to pass a parameter prefix"
	echo
	echo "e.g. ./utl_gen_pvt_and_csr.sh <System Name> where <SYS> like 'dde' or 'ddedev' or 'pfp' or 'fs56' etc - without the quotes, no spaces"
	echo
	echo "sample:    ./utl_gen_pvt_and_csr.sh ddedev"
	echo
	exit 8
fi

#SYS="fs56"
DTE=$(date +"%Y%m%d")
#DTE="20250311"
CFG=$(echo "$SYS-openssl.cnf")

if [ ! -s $CFG ];then
  echo "ERROR:   Your config file is missing"
  echo "Please create $CFG first and rerun"
  exit 8
fi

NAM=$(echo "$SYS-$DTE")

FULLNAM=$(echo $NAM"-private.key")
NEWCSR=$(echo $NAM"-new_csr.csr")

openssl genrsa -out $FULLNAM 2048

openssl req -new -key $FULLNAM -out $NEWCSR -config $CFG

