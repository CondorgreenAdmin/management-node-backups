#!/bin/bash
#
#	Script to update the file /root/notes.txt
#	2017-11-09
#
#       Format
# Name : <YOUR NAME>
# Date : <THE DATE TODAY>
# Notes : <THE DETAIL YOU WANT TO BE NOTED>
#
THE_HOST=`hostname`
THE_TTY=`tty | cut -c6-`
THE_USER=`w | grep $THE_TTY | awk '{print $1}'`
THE_IPADDR=`w | grep $THE_TTY | awk '{print $3}'`
THE_WHEN=`date +%Y-%m-%d_%H:%M:%S`
#
read -p " Please enter the notes description: " THE_NOTE
echo -e "Name : "$THE_USER >> /root/notes.txt
echo -e "Date : "$THE_WHEN >> /root/notes.txt
echo -e "Note : "$THE_NOTE >> /root/notes.txt
echo -e "Note : ============================" >> /root/notes.txt

tail /root/notes.txt
echo "****THANK-YOU FOR UPDATING THE NOTES****"

