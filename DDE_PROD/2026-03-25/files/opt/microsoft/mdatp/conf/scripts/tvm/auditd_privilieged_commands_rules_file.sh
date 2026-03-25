#!/usr/bin/env sh

output="" missing="" line="" rchk=""
uid_min_val=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

for file in $(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f); do
	line=$(printf "$file" | awk '{print "^\\h*-a\\h+(always,exit|exit,always)\\h+-F\\h+path=" $1 "\\h+-F\\h+perm=x\\h+-F\\h+auid>='"$uid_min_val"'\\h+-F\\h+auid!=(unset|-1|4294967295)\\h+(-k\\h+\\H+|-F\\h*key=\\H+)\\h*(#.*)?$" }')
	rchk=$(grep -P -- "$line" /etc/audit/rules.d/*.rules)
	if [ -n "$rchk" ]; then
		output="$output\\naudit rule \"$(printf "$rchk" | awk -F: '{print $2}')\"\\nexists in the file: \"$(printf "$rchk" | awk -F: '{print $1}')\"\\n"
	else
		missing="$missing\\nmissing audit rule for file: \"$file\""
	fi
done

# if no files are missing an auditd rule in the .rules file we pass
if [ -z "$missing" ];then
	echo -e "$output"
	exit 0
else
	# print files missing auditd rules in the .rules files
	echo -e "$missing"
	exit 1
fi