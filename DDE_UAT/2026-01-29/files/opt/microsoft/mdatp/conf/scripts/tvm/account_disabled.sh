#!/usr/bin/env sh

[ -z "$(awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $1!~/^\+/ && $3<'"$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"' && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false" && $7!="/usr/bin/false") {print}' /etc/passwd)" ] && passing=true

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "system accounts login is disabled"
	exit 0
else
    # print the reason why we are failing
	echo "System account: \"$(awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $1!~/^\+/ && $3<'"$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)"' && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false" && $7!="/usr/bin/false") {print $1}' /etc/passwd)\" login is not disabled"
	exit 1
fi