#!/usr/bin/env sh

passing="" output=""

if command -v firewall-cmd >/dev/null; then
	firewall-cmd --state | grep -iq "$1" && passing=true
	output="firewalld state is: \"$(firewall-cmd --state)\""
fi

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "nftables or iptables are being used on this system"
	exit 0
else
    # print the reason why we are failing
	echo "FAILED"
	if [ -n "$output" ]; then
		echo "$output"
	else
		echo "FirewallD command \"firewall-cmd\" not avaliable on the system"
	fi
	exit 1
fi