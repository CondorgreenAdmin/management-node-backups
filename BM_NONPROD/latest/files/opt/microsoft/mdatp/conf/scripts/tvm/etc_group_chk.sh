#!/usr/bin/env sh

passing=""
output=""
EPG=""
EGG=""

EPG=$(cut -d: -f4 /etc/passwd | uniq)
EGG=$(cut -d: -f3 /etc/group | uniq)
for group in $EPG; do
#	if ! grep -Eq "^$group$" <<< "$EGG"; then
	if [ -z "$(echo "$EGG" | grep -E "(^|\s)$group\b")" ]; then
		[ -n "$output" ] && output="$output $group" || output=$group
	fi
done
[ -z "$output" ] && passing=true
# If the test passes, we pass
if [ "$passing" = true ] ; then
	echo "All groups in /etc/passwd exist in /etc/group"
    exit 0
else
    # print the reason why we are failing
    echo "The group(s) \"$output\" exist in /etc/passwd but don't exist in /etc/group"
    exit 1
fi