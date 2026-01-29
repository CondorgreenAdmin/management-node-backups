#!/usr/bin/env sh

WBP="/etc/issue"

if [ -s "$WBP" ] ; then
	[ -z "$(grep -Ei "(\\\v|\\\r|\\\m|\\\s|$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/"//g'))" $WBP)" ] && passing=true
else
	passing=true
fi

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "Warning Banner \"$WBP\" passed"
    exit 0
else
    # print the reason why we are failing
    echo "Warning Banner contains: $(grep -E "(\\\v|\\\r|\\\m|\\\s|$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/"//g'))" $WBP)"
    exit 1
fi