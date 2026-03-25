#!/usr/bin/env sh

if echo "$1" | grep -Pq -- 'auid(>|>=|=>)' ; then
	sysuid="$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"
#	REGEXCHK="$(echo "$1" | sed -r "s/auid(>=|>|=>)([0-9]+)/auid>=$sysuid/g")"
	REGEXCHK="$(printf '%s' "$1" | sed -r "s/auid(>=|>|=>)([0-9]+)/auid>=$sysuid/g")"
	output="$(grep -P -s -- "$REGEXCHK" /etc/audit/rules.d/*.rules | cut -d: -f2)"
	location="$(grep -P -l -s -- "$REGEXCHK" /etc/audit/rules.d/*.rules)"
else
	output="$(grep -P -s -- "$1" /etc/audit/rules.d/*.rules | cut -d: -f2)"
	location="$(grep -P -l -s -- "$1" /etc/audit/rules.d/*.rules)"
fi

# If the regex matched, output would be generated.  If so, we pass
if [ -n "$output" ] ; then
	echo "PASSED"
	echo "audit rule: \"$output\""
	echo "exists in: \"$location\""
    exit 0
else
    # print the reason why we are failing
    if [ -n "$REGEXCHK" ] ; then
    	echo "FAILED"
    	echo "No auditd rules were found in any /etc/audit/rules.d/*.rules file matching the regular expression:"
    	echo "$REGEXCHK"
    else
    	echo "FAILED"
    	echo "No auditd rules were found in any /etc/audit/rules.d/*.rules file matching the regular expression:"
    	echo 1
    fi
    exit 1
fi