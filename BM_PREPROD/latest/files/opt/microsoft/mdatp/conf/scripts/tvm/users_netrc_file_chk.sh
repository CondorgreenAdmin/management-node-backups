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
		file="$dir/.netrc"
		if [ ! -h "$file" ] && [ -f "$file" ]; then
			if stat -L -c "%A" "$file" | cut -c4-10 |  grep -E '[^-]+'; then
				[ -z "$output2" ] && output2="User: \"$user\" file: \"$file\" exists with permissions: \"$(stat -L -c "%a" "$file")\"" || output2="$output2; User: \"$user\" file: \"$file\" exists with permissions: \"$(stat -L -c "%a" "$file")\""
			else
				[ -z "$output3" ] && output3="User: \"$user\" file: \"$file\" exists with permissions: \"$(stat -L -c "%a" "$file")\"" || output3="$output3; User: \"$user\" file: \"$file\" exists with permissions: \"$(stat -L -c "%a" "$file")\""
			fi
		fi
	fi
done

[ -z "$output2" ] && passing=true

# If passing is true, we pass
if [ "$passing" = true ] ; then
	echo "Passed: All users' .netrc files are \"600\" or more restrictive"
	[ -n "output3" ] && echo "WARNING: $output3"
	[ -n "$output" ] && echo "INFO: $output"
    exit 0
else
    # print the reason why we are failing
    echo "FAILED: $output2"
    [ -n "output3" ] && echo "WARNING: $output3"
    [ -n "$output" ] && echo "INFO: $output"
    exit 1
fi