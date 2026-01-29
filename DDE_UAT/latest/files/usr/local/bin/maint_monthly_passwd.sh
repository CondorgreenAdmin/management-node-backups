#!/bin/bash
#
#
#	Display the content of the file
if [ -f /etc/monthly_password ]
then
	whiptail --scrolltext --title "Current content of /etc/monthly_password" --textbox /etc/monthly_password 20 50
else
	whiptail --title "/etc/monthly_password" --msgbox "**** File does not exist " 10 50
fi
#
#	Prompt to the new user name
NEW_USER=$(whiptail --title "Enter the username to be added " --inputbox "New UserName " 10 50 3>&1 1>&2 2>&3)
#
#	Check if user exists in /etc/passwd
LOCAL_CHECK=`grep "^$NEW_USER:" /etc/passwd &> /dev/null ; echo $?` 
MTHPASW_CHECK=`grep "^$NEW_USER" /etc/monthly_password &> /dev/null ; echo $?` 
if [ $LOCAL_CHECK -ne 0 -o $MTHPASW_CHECK -eq 0 ] 
then
	whiptail --title "User check " --msgbox "User either does not exist on the server or is already added " 10 50
	exit
fi	
#
NEW_USER_LEN=`echo $NEW_USER | wc -c`
if [ $NEW_USER_LEN -eq 1 ]
then
	echo "No Username entered"
	exit
fi
#
whiptail --title "Final Confirmation" --yesno "New username to be added is $NEW_USER " 10 60
exitstatus=$?
if [ $exitstatus = 1 ]; then
    echo "You chose Cancel."
    exit
else
    echo "ExitStatus = " $exitstatus
    echo "You chose Continue"
    if [ -f /etc/monthly_password ]
    then
	chattr -i /etc/monthly_password
    fi
    echo $NEW_USER >> /etc/monthly_password
    chattr +i /etc/monthly_password
fi
