#!/usr/bin/env sh
# Note: we manually changed the interpreter from bash to sh as currently running with sh and the script had bash syntax

output=""

ufw_out="$(ufw status verbose)"
for lpn in $(ss -tuln | awk '($5!~/%lo:/ && $5!~/127.0.0.1:/ && $5!~/::1/) {split($5, a, ":"); print a[2]}' | sort | uniq); do
	 echo "$ufw_out" | grep -Pqv "^\h*$lpn\b" && output="$output\n- Port: \"$lpn\" is missing a firewall rule"
done

# for i in $( ss -4tuln | grep LISTEN | grep -Ev "(127\.0\.0\.1|\:\:1)" | sed -E "s/^(\s*)(tcp|udp)(\s+\S+\s+\S+\s+\S+\s+\S+:)(\S+)(\s+\S+\s*$)/\4/") ; do
#	 ufw status | grep -Eq -- "$i(\/(tcp|udp))?\s+.*(ALLOW|DENY)" || passing=""
# done

# If the regex matched, output would be generated.  If so, we pass
if [ -z "$output" ] ; then
	echo -e "PASS:\nAll listening ports have a firewall rule"
	exit 0
else
    # print the reason why we are failing
	echo -e "FAIL:\n$output"
	exit 1
fi