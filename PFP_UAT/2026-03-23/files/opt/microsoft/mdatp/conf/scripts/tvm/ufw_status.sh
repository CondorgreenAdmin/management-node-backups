#!/usr/bin/env sh

ufw status verbose | grep -Eq "$1" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "Missing ufw rule."
    exit 1
fi