#!/usr/bin/env sh

arch | grep -vq "x86_64" && passing="true"

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "system is running: $(arch)"
    exit 1
fi