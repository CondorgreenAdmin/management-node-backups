#!/usr/bin/env sh

if [ -n "$(command -v journalctl)" ] ; then
	journalctl | grep -q 'protection: active' && output="passed"
elif [ -s "/var/log/dmesg" ] && [ -s "/proc/info" ] && [ -s "/var/log/dmesg" ] ; then
	if [ -n "$(grep 'noexec[0-9]*=off' /proc/cmdline)" ] || [ -z "$(grep -E -i ' (pae|nx) ' /proc/cpuinfo)" ] || [ -n "$(grep '\sNX\s.*\sprotection:\s' /var/log/dmesg | grep -v active)" ] ; then
		output="failed"
	else
		output="passed"
	fi
else
	output="failed"
fi

# output variable set for pass or fail, if pass we pass
if [ "$output" = "passed" ] ; then
	echo "XD/ND support enabled"
    exit 0
else
    # print the reason why we are failing
    echo "XD/ND support is not enabled"
    exit 1
fi
