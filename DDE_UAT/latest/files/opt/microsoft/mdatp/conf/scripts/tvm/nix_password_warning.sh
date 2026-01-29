#!/usr/bin/env sh

passing="" output=""

awk -F : '/^[^:]+:[^\!*]/{print $1 " " $6}' /etc/shadow | (while read -r usr days; do
	if [ "$days" -ge "$1" ] && [ "$days" -gt 0 ]; then
		[ -z "$output" ] && passing=true
	else
		passing=""
		[ -z "$output" ] && output="FAILED: User: \"$usr\" password expiration warning is: \"$days\" days" || output="$output, User: \"$usr\" password expiration warning is: \"$days\" days"
	fi
done

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "PASSED: All uses password expiration warning is 7 days or more"
	exit 0
else
    # print the reason why we are failing
	echo "$output"
	exit 1
fi
)