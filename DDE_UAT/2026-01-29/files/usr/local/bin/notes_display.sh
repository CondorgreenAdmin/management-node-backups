#!/bin/bash
#
#	Script to display the file /root/notes.txt
#	2017-11-09
#
THE_HOST=`hostname`
THE_TTY=`tty | cut -c6-`
THE_USER=`w | grep $THE_TTY | awk '{print $1}'`
THE_IPADDR=`w | grep $THE_TTY | awk '{print $3}'`
THE_WHEN=`date +%Y-%m-%d_%H:%M:%S`
#
less /root/notes.txt

