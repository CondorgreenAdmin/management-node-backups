#!/usr/bin/env sh

nmcli radio all | grep -Eq "^\s*\S+\s+disabled\s+\S+\s+disabled\s*$" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "Wireless is disabled"
    exit 0
else
    # print the reason why we are failing
    echo "Wireless is not disabled"
    exit 1
fi