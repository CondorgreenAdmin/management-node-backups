#!/usr/bin/env sh

nft list ruleset | grep -Pq "$1" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "Missing nftables rule."
    exit 1
fi