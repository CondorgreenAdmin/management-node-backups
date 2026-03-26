#!/usr/bin/env sh

nftni=""
nftd=""
nonft=""
ufwe=""
passing=""
# Test to determine if UFW is being used
if dpkg-query -s ufw 2>/dev/null | grep -q 'Status: install ok installed'; then
	ufw status | grep -q 'Status: active' && ufwe=y
fi
# Tests to determine if iptables is being used
dpkg-query -s iptables-persistent 2>/dev/null | grep -q 'Status: install ok installed' && iptpi=y
# Tests to determine that nftables is not in use
if ! dpkg-query -s nftables 2>/dev/null | grep -q 'Status: install ok installed'; then
	nftni=y
else
	systemctl is-enabled nftables 2>/dev/null | grep -q "masked" && systemctl status nftables 2>/dev/null | grep -q "Active: inactive (dead) " && nftd="y"
fi

if [ "$nftni" = y ] || [ "$nftd" = y ] ; then
	nonft="y"
fi
# Test if NFTables is not used
if [ "$nonft" = y ]; then
	if [ "$ufwe" = y ] || [ "$iptpi" = y ]; then
		passing=true
	fi
fi

# If nftables is not required, passing is set to true. If so, we pass
if [ "$passing" = true ] ; then
	[ "$nonft" = y ] && echo "NFTables is not in use on the system"
	[ "$ufwe" = y ] && echo "UFW is in use on the system"
	[ "$iptpi" = y ] && echo "IPTables is in use on the system"
    exit 0
else
    # print the reason why we are failing
    [ "$nonft" != y ] && echo "NFTables is in use on the system"
    [ "$ufwe" != y ] && echo "UFW is not configured"
    [ "$iptpi" != y ] && echo "IPTables is not configured"
    exit 1
fi