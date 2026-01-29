#!/usr/bin/env sh

passing=""
output=""
output2=""
user=""
dir=""

for i in $( awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ && $7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {print $1":"$6}' /etc/passwd); do
	user=$(echo "$i" | cut -d: -f1)
	dir=$(echo "$i" | cut -d: -f2)
	if [ ! -d "$dir" ]; then
		[ -z "$output2" ] && output2="The following users' home directories don't exist: \"$user\"" || output2="$output2, \"$user\""
	else
		owner="$(stat -L -c "%U" "$dir")"
		if [ "$owner" != "$user" ]; then
			[ -z "$output" ] && output="The following users' don't own their home directory: \"$user\" home directory is owned by \"$owner\"" || output="$output, \"$user\" home directory is owned by \"$owner\""
		fi
	fi
done

[ -z "$output" ] && passing=true

# If passing is true, we pass
if [ "$passing" = true ] ; then
	echo "Passed.  All users own their home directory"
	[ -n "$output2" ] && echo "WARNING: $output2"
    exit 0
else
    # print the reason why we are failing
    [ -n "$output" ] && echo "$output"
    [ -n "$output2" ] && echo "WARNING: $output2"
    exit 1
fi