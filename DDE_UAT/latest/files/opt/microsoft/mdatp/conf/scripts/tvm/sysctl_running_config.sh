#!/usr/bin/env sh

sysctl -a | grep -Eq "$1" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "sysctl parameter is: $(sysctl -a | grep -E "$1")"
    exit 0
else
    # print the reason why we are failing
    echo "Missing sysctl parameter."
    exit 1
fi