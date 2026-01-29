#!/bin/bash

# Global variables
MDEP_PF_ANCHOR_FILE="/etc/pf.anchors/com.microsoft"
MDEP_PF_RULES_FILE="/etc/pf.rules/pfmdep.rule"
MAC_PF_CONF_FILE="/etc/pf.conf"
MDEP_PF_DAEMON_FILE="/Library/LaunchDaemons/com.isolate.pfctl.plist"
MDEP_PF_CURRENT_STATUS_FILE="/etc/mdep_lr_pf_status"

function restore_pf()
{
	# Machine is rebooted, file gets removed and no need to anything
	[ ! -e $MDEP_PF_CURRENT_STATUS_FILE ] && return;

	PF_STATUS=`cat $MDEP_PF_CURRENT_STATUS_FILE`

	if [ "$PF_STATUS" = "Disabled" ]; then
		pfctl -d > /dev/null 2>&1
	else
		pfctl -e -f $MAC_PF_CONF_FILE > /dev/null 2>&1
	fi

	rm -f $MDEP_PF_CURRENT_STATUS_FILE
}

function unisolate_machine()
{
   # Unload the pfctl daemon
   if [ -e $MDEP_PF_DAEMON_FILE ]; then
      launchctl unload $MDEP_PF_DAEMON_FILE > /dev/null 2>&1
      rm -f $MDEP_PF_DAEMON_FILE > /dev/null 2>&1
   fi

   # Disable PF
   pfctl -d > /dev/null 2>&1

   # Remove anchor and rule's file
   if [ -e $MDEP_PF_ANCHOR_FILE ] && [ -e $MDEP_PF_RULES_FILE ]; then
      rm -f $MDEP_PF_ANCHOR_FILE $MDEP_PF_RULES_FILE
   fi

   # remove entry from conf file
   sed -i '' -e '/microsoft/d' "$MAC_PF_CONF_FILE" > /dev/null 2>&1

	# Based on previous PF status take action
	restore_pf

   # We are running this script only when we failed to download the script. Presumably because of the earlier
   # isolation command. This script will be run instead of the command that customer wanted to run and release the isolation
   echo "Isolation released - Failed to download the script. Please try again"
}

unisolate_machine