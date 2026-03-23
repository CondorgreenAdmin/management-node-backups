#!/usr/bin/env sh

output=$(
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -0002 -printf "World-Writable file %p\n" 2>/dev/null
)

# we captured output of the subshell, let's interpret it
if [ "$output" != "" ] ; then
    # print the reason why we are failing
    echo "$output"
    exit 1
else
    exit 0
fi