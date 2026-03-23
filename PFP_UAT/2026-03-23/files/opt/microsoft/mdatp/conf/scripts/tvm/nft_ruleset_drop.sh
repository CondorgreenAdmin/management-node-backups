#!/usr/bin/env sh

CHAIN="$1"

nft list ruleset | grep -Eq "^\s*type\s+filter\s+hook\s+$CHAIN\s+(priority\s+\S+;\s+)*policy\s+drop;" && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
    exit 0
else
    # print the reason why we are failing
    echo "\"$1\" basechain does not have a default drop policy"
    exit 1
fi