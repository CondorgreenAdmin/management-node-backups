#!/bin/sh
#
#  Licensed Materials - Property of IBM and/or HCL
#
#  IBM Informix Dynamic Server
#  (c) Copyright IBM Corporation 1996, 2011 All rights reserved.
#  (c) Copyright HCL Technologies Ltd. 2017, 2022.  All Rights Reserved.
#
#
#  Name        : cmalarmprogram.sh
#  Created     : Jan 2011
#  Description : Automates many CM events using event alarms from the
#               Connection Manager. To install this script, add the following
#               line to the CM configuration file :
#                  CMALARMPROGRAM    $INFORMIXDIR/etc/cmalarmprogram.sh
#               This script sends email and pages the systems group when necessary.
#
#  /**************************************************************************/


# ########################################
#
# PUBLIC SECTION : CONFIGURATION VARIABLES
#
# ########################################

ALARMADMIN=0
ALARMPAGER=0
ADMINEMAIL=
PAGEREMAIL=

MAILUTILITY=/usr/bin/mail





# ########################################
#
#     PRIVATE SECTION : EVENT HANDLERS      
#
# ########################################

ALRM_NOTWORTHY=1
ALRM_INFO=2
ALRM_ATTENTION=3
ALRM_EMERGENCY=4
ALRM_FATAL=5

EVENT_SEVERITY=$1
EVENT_CLASS=$2
EVENT_MSG="$3"
EVENT_ADD_TEXT="$4"
# If this alarm is for a specific connection unit then the unit's name is
# included in EVENT_ADD_TEXT.  It is also available via the 
# INFORMIXCMCONUNITNAME environment variable.
EVENT_UNIQID="$5"

RM="rm -f"
ONSTATCMD="onstat"
MAILBODY=/tmp/__MAILBODY_$$
MAILHEAD=/tmp/__MAILHEAD_$$
TMPFILE=/tmp/__TMPFILE_$$
ALARMTESTFILE=


osname=$(uname -s)
if [ "${osname}" = "SunOS" ]
then
    AWK="nawk"
else
    AWK="awk"
fi


# /* Keep track of the last 5 minutes of the alarm log */
LASTALARMFILE=/tmp/.lastcmalarm_${INFORMIXCMNAME}
touch "${LASTALARMFILE}"
CURRENT=/tmp/.cmalarm_$$
DATE_INT=$(date +%Y%j%H%M%S); export DATE_INT  # Do not delete the export command
${AWK} -v CT=${DATE_INT} '{ if ($1 >= (CT-300)) print $0 }' ${LASTALARMFILE} > ${CURRENT}
mv ${CURRENT} "${LASTALARMFILE}"

# In order to avoid sending incorrect mails ALARMADMIN and ALARMPAGER
# must be correctly configured.  If they are out of range or unset 
# they will be reset to 0 (deactivated).
if [ "x${ALARMADMIN}" = "x" ]
then
    echo "ALARMADMIN is unset, setting it to 0."
    ALARMADMIN=0
elif [ ${ALARMADMIN} -lt 0 ] || [ ${ALARMADMIN} -gt 5 ]
then
    echo "ALARMADMIN is out of range, reseting it to 0 from ${ALARMADMIN}"
    ALARMADMIN=0
fi

if [ "x${ALARMPAGER}" = "x" ]
then
    echo "ALARMPAGER is unset, setting it to 0."
    ALARMPAGER=0
elif [ ${ALARMPAGER} -lt 0 ] || [ ${ALARMPAGER} -gt 5 ]
then
    echo "ALARMPAGER is out of range, reseting it to 0 from ${ALARMPAGER}"
    ALARMPAGER=0
fi

case "${EVENT_SEVERITY}" in
      1)
        EVENT_SEVERITY_NAME="trivia"
         ;;
      2)
        EVENT_SEVERITY_NAME="information"
         ;;
      3)
        EVENT_SEVERITY_NAME="Attention!"
         ;;
      4)
        EVENT_SEVERITY_NAME="EMERGENCY!!"
         ;;
      5)
        EVENT_SEVERITY_NAME="FATAL EVENT!!!"
         ;;
esac

# Cleanup the mail header and the mail body file
${RM} ${MAILBODY} ${MAILHEAD} ${TMPFILE}

case "${EVENT_CLASS}" in
      1) 
        printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
      2)
	printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
      3)
	printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
      4)
	printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
      5)
	printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
      *)
	printf "Subject: %s : %s : %s\n" "${INFORMIXCMNAME}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> ${MAILHEAD}
        printf "%s\n" "${EVENT_ADD_TEXT}" >> ${MAILBODY}
         ;;
esac

NOSENDER=1
# Send e-mail to who may be interested
if [ ${ALARMADMIN} -ne 0 ]
then
  if [ "${EVENT_SEVERITY}" -ge ${ALARMADMIN} ]
  then
    if [ "x${ADMINEMAIL}" != "x" ]
      then
      printf "To: %s\n" ${ADMINEMAIL}  >> ${MAILHEAD}
      MAILTO=${ADMINEMAIL}
      NOSENDER=0
    fi
  else
    echo "Event Severity = ${EVENT_SEVERITY} is lower than ALARMADMIN=${ALARMADMIN}"
    echo "No mail will be sent to ALARMEMAIL"
  fi
fi

if [ ${ALARMPAGER} -ne 0 ]
then
  if [ "${EVENT_SEVERITY}" -ge ${ALARMPAGER} ]
  then
    if [ "x${PAGEREMAIL}" != "x" ]
    then
      if [ ${NOSENDER} -eq 0 ]
      then 
        printf "cc: %s\n" ${PAGEREMAIL}  >> ${MAILHEAD}
        MAILTO=${MAILTO},${PAGEREMAIL}
      else
        printf "To: %s\n" ${PAGEREMAIL}  >> ${MAILHEAD}
        MAILTO=${PAGEREMAIL}
      fi
    fi
  else
    echo "Event Severity = ${EVENT_SEVERITY} is lower than ALARMPAGER=${ALARMPAGER}"
    echo "No mail will be sent to PAGEREMAIL"
  fi
fi

if [ "x${MAILTO}" != "x" ]
then
  printf "\n" >> ${MAILHEAD}
  cat ${MAILBODY} >> ${MAILHEAD}
  if [ "x${ALARMPROGRAMTEST}" = "x" ]
  then
    if [ "x${MAILUTILITY}" != "x" ]
    then
      ## Do not send same alarm in less than 5 minute interval.
      if [ "$(grep "${EVENT_MSG}" "${LASTALARMFILE}" -c)" -lt 1 ]
      then
        ${MAILUTILITY} ${MAILTO} < ${MAILHEAD}
      fi
    else
      echo "MAILUTILITY is not set, NO MAIL will be sent."
    fi
  else
    cat ${MAILHEAD} >> ${ALARMTESTFILE}
  fi
else
  echo "SENDER IS NULL NO MAIL WILL BE SENT"
fi

printf "%s : %s : %s\n" "${DATE_INT}" "${EVENT_SEVERITY_NAME}" "${EVENT_MSG}" >> "${LASTALARMFILE}"

$RM ${MAILHEAD} ${MAILBODY} ${TMPFILE} ${CURRENT}
