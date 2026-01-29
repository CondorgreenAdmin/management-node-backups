#!/usr/bin/env sh

[ -n "$(echo "$1" | grep -E '^\s*-')" ] && 1="^\s*$1"

if [ -n "$(echo "$1" | grep -E 'auid(>|>=|=>)')" ] ; then
	sysuid="$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"
	REGEXCHK="$(echo "$1" | sed -r "s/^(.*)(auid(>=|>)\S+)(\s+-[A-Z].*)$/\1auid\3$sysuid\4/")"
	output="$(auditctl -l | grep -E "$REGEXCHK")"
else
	output="$(auditctl -l | grep -E "$1")"
fi

# If the regex matched, output would be generated.  If so, we pass
if [ -n "$output" ] ; then
	echo "audit rule: \"$output\" exists in the running auditd config"
	exit 0
else
	# print the reason why we are failing
	if [ -n "$REGEXCHK" ] ; then
		echo "No auditd rules were found matching the regular expression $REGEXCHK"
	else
		echo "No auditd rules were found matching the regular expression $1"
	fi
#	echo "1 is: $1"
#	echo "REGEXCHK is: $REGEXCHK"
	exit 1
fi