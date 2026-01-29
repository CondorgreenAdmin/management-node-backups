#!/usr/bin/env sh

sestatus | grep -Eq "$1" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "SELinux status for \"$1\" not found"
    exit 1
fi