#!/usr/bin/env sh

passing=""
output=""
output2=""
user=""
dir=""

for i in $(awk -F: '($1!~/(halt|sync|shutdown)/ && $7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {print $1":"$6}' /etc/passwd); do
	user=$(echo "$i" | cut -d: -f1)
	dir=$(echo "$i" | cut -d: -f2)
	if [ ! -d "$dir" ]; then
		[ -z "$output" ] && output="The following users' home directories don't exist: \"$user\"" || output="$output, \"$user\""
	else
		file="$dir/$1"
		if [ ! -h "$file" ] && [ -f "$file" ]; then 
			[ -z "$output2" ] && output2="User: \"$user\" file: \"$file\" exists" || output2="$output2; User: \"$user\" file: \"$file\" exists"
		fi
	fi
done

[ -z "$output2" ] && passing=true

# If passing is true, we pass
if [ "$passing" = true ] ; then
	echo "Passed: No \"$1\" file exist in users' home directories"
	[ -n "$output" ] && echo "WARNING: $output"
    exit 0
else
    # print the reason why we are failing
    echo "FAILED: $output2"
    [ -n "$output" ] && echo "WARNING: $output"
    exit 1
fi