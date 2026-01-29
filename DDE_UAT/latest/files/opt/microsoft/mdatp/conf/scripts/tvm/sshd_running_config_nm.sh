#!/usr/bin/env sh

passing=""
output=""
hn=$(hostname)
ha=$(grep "$hn" /etc/hosts | awk '{print $1}')

if echo "$1" | grep -Eq '^\^\\s\*'; then
	output="$(sshd -T -C user=root -C host="$hn" -C addr="$ha" | grep -E "$(echo "$1" | cut -d'*' -f2 | cut -d'\' -f1)")"
else
	output="$(sshd -T -C user=root -C host="$hn" -C addr="$ha" | grep -E "$(echo "$1" | cut -d'\' -f1)")"
fi

[ -z "$(sshd -T -C user=root -C host="$hn" -C addr="$ha" | grep -E "$1")" ] && passing="true"

# If the regex matched, the test would fail, otherwise we pass.
if [ "$passing" = true ] ; then
	echo "PASSED! sshd parameter: \"$output\""
    exit 0
else
    # print the reason why we are failing
    echo "FAILED! check sshd parameter: \"$output\""
    exit 1
fi