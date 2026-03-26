#!/usr/bin/env sh

passing=true

find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit (-S all )?-F path=" $1 " -F perm=x -F auid>='"$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"' -F auid!=-1 -F key=" }' | ( while read -r line
do
  auditctl -l | grep -E -- "^$line\S+ *$" || passing=false
done

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "Missing auditd rules."
    exit 1
fi
)
