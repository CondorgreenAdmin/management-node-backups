#!/usr/bin/env sh

tst1="$(systemctl show "$1" | awk -F '=' '/UnitFileState=/ {print $2}')"
tst2="$(systemctl show "$1" | awk -F '=' '/ActiveState=/ {print $2}')"
output="Service $1 is $tst1 and $tst2"

if [ "$tst1" = "enabled" ] && [ "$tst2" = "active" ]; then
	echo "PASSED:"
	echo "$output"
	exit 0
else
	# print the reason why we are failing
	echo "FAILED:"
	echo "$output"
	exit 1
fi