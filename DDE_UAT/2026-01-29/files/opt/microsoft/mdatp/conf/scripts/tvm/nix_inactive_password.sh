#!/usr/bin/env sh

passing="" output=""

awk -F : '/^[^:]+:[^\!*]/{print $1 " " $7}' /etc/shadow | (while read -r usr days; do
	if [ "$days" -le "$1" ] && [ "$days" -gt 0 ]; then
		[ -z "$output" ] && passing=true
	else
		passing=""
		[ -z "$output" ] && output="FAILED: User: \"$usr\" inactive password lock is: \"$days\" days" || output="$output, User: \"$usr\" inactive password lock is: \"$days\" days"
	fi
done

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "PASSED: All uses inactive password lock is 30 days or less"
	exit 0
else
    # print the reason why we are failing
	echo "$output"
	exit 1
fi
)