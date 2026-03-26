#!/usr/bin/env bash

l_output="" l_output2=""
l_kpname="$(printf "%s" "$1" | awk -F= '{print $1}' | xargs)"
l_kpvalue="$(printf "%s" "$1" | awk -F= '{print $2}' | xargs)"
l_searchloc="/run/sysctl.d/*.conf /etc/sysctl.d/*.conf /usr/local/lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /lib/sysctl.d/*.conf /etc/sysctl.conf $([ -f /etc/default/ufw ] && awk -F= '/^\s*IPT_SYSCTL=/ {print $2}' /etc/default/ufw)"
l_krp="$(sysctl "$l_kpname" | awk -F= '{print $2}' | xargs)"
l_pafile="$(grep -Psl -- "^\h*$l_kpname\h*=\h*$l_kpvalue\b\h*(#.*)?$" $l_searchloc)"
l_fafile="$(grep -s -- "^\s*$l_kpname" $l_searchloc | grep -Pv -- "\h*=\h*$l_kpvalue\b\h*" | awk -F: '{print $1}')"
if [ "$l_krp" = "$l_kpvalue" ]; then
   l_output="$l_output\n - \"$l_kpname\" is set to \"$l_kpvalue\" in the running configuration"
else
   l_output2="$l_output2\n - \"$l_kpname\" is set to \"$l_krp\" in the running configuration"
fi
if [ -n "$l_pafile" ]; then
   l_output="$l_output\n - \"$l_kpname\" is set to \"$l_kpvalue\" in \"$l_pafile\""
else
   l_output2="$l_output2\n - \"$l_kpname = $l_kpvalue\" is not set in a kernel parameter configuration file"
fi
[ -n "$l_fafile" ] && l_output2="$l_output2\n - \"$l_kpname\" is set incorrectly in \"$l_fafile\""
if [ -z "$l_output2" ]; then
   echo -e "\n- Audit Result:\n  ** PASS **\n$l_output\n"
   exit 0
else
   echo -e "\n- Audit Result:\n  ** FAIL **\n - Reason(s) for audit failure:\n$l_output2\n"
   [ -n "$l_output" ] && echo -e "\n- Correctly set:\n$l_output\n"
   exit 1
fi