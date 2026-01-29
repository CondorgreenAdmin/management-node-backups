#!/usr/bin/env sh

if echo "$1" | grep -Pq -- 'auid(>|>=|=>)' ; then
	sysuid="$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"
#	REGEXCHK="$(echo "$1" | sed -r "s/auid(>=|>|=>)([0-9]+)/auid>=$sysuid/g")"
	REGEXCHK="$(printf '%s' "$1" | sed -r "s/auid(>=|>|=>)([0-9]+)/auid>=$sysuid/g")"
	output="$(auditctl -l | grep -P -- "$REGEXCHK")"
else
	output="$(auditctl -l | grep -P -- "$1")"
fi

# If the regex matched, output would be generated.  If so, we pass
if [ -n "$output" ] ; then
	echo "PASSED"
	echo "audit rule: \"$output\""
	echo "exists in the running auditd config"
	exit 0
else
	# print the reason why we are failing
	if [ -n "$REGEXCHK" ] ; then
		echo "FAILED"
		echo "No auditd rules were found in the running config matching the regular expression:"
		echo "$REGEXCHK"
	else
		echo "FAILED"
		echo "No auditd rules were found in the running config matching the regular expression:"
		echo "$1"
	fi
	exit 1
fi