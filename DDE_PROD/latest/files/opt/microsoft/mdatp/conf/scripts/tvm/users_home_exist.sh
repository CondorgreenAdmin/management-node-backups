#!/usr/bin/env sh

passing=""
output=""
user=""
dir=""

for i in $( awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ && $7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {print $1":"$6}' /etc/passwd); do
	user=$(echo "$i" | cut -d: -f1)
	dir=$(echo "$i" | cut -d: -f2)
	if [ ! -d "$dir" ]; then
		[ -z "$output" ] && output="User \"$user\" missing home directory \"$dir\"" || output="$output; User \"$user\" missing home directory \"$dir\""
	fi
done

[ -z "$output" ] && passing=true

# If passing is true, we pass
if [ "$passing" = true ] ; then
	echo "Passed.  All users have a home directory"
    exit 0
else
    # print the reason why we are failing
    echo "$output"
    exit 1
fi