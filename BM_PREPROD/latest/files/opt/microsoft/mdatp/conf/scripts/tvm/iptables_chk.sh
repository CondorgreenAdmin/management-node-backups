#!/usr/bin/env sh

iptables -L -n | grep -Eq "$1" && passing="true"

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "Missing iptables rule."
    exit 1
fi