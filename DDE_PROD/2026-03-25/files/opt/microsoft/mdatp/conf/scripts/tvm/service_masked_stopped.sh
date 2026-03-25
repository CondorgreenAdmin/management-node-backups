#!/usr/bin/env sh
passing=""

tst1="$(systemctl show "$1" | awk -F '=' '/UnitFileState=/ {print $2}')"
[ -z "$tst1" ] && tst1="$(systemctl show "$1" | awk -F '=' '/LoadState=/ {print $2}')"
tst2="$(systemctl show "$1" | awk -F '=' '/ActiveState=/ {print $2}')"
output="Service $1 is $tst1 and $tst2"

if [ "$tst1" = "masked" ] || [ "$tst1" = "not-found" ]; then
	[ "$tst2" = "inactive" ] && passing="true"
fi

if [ "$passing" = "true" ]; then
	# print the reason why we are passing
	echo "PASSED:"
	echo "$output"
	exit 0
else
	# print the reason why we are failing
	echo "FAILED:"
	echo "$output"
	exit 1
fi