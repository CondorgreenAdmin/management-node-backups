#!/usr/bin/env sh

output=""

awk -F: -v GID="$(awk -F: '($1=="shadow") {print $3}' /etc/group)" '($4==GID) {print $1}' /etc/passwd | (while read -r usr; do
	[ -z "$output" ] && output="\"$usr\"" || output=",\"$usr\""
done

# If the regex matched, output would be generated.  If so, we pass
if [ -z "$output" ] ; then
	echo "PASSED: No users have group shadow as their primary group"
	exit 0
else
    # print the reason why we are failing
	echo "FAILED: Then following user(s) have group shadow as their primary group"
	echo "$output"
	exit 1
fi
)