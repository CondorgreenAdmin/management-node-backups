#!/usr/bin/env sh

passing=""
output=""

if dpkg-query -s ufw 2>/dev/null | grep -q 'Status: install ok installed';then
	output=$(ufw status | grep 'Status')
	ufw status | grep 'Status: active' && passing=true
else
	output="UFW is not installed"
fi

# If passing is true, we pass
if [ "$passing" = true ] ; then
	echo "Passed. UFW status is: \"$output\""
    exit 0
else
    # print the reason why we are failing
    echo "Failed. UFW status is: \"$output\""
    exit 1
fi