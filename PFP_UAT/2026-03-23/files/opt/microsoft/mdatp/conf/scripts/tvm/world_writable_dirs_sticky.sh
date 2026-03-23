#!/usr/bin/env sh

PATH=/bin:/usr/bin

output=$(
df --local -P 2> /dev/null | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -printf "%p is %m should be 1777\n" 2>/dev/null
)

# we captured output of the subshell, let's interpret it
if [ "$output" != "" ] ; then
    # print the reason why we are failing
    echo "$output"
    exit 1
else
    exit 0
fi
