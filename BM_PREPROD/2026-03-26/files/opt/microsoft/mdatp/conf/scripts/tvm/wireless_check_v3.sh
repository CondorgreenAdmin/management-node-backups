#!/usr/bin/env sh

if command -v mnci >/dev/null 2>&1 ; then
	nmcli radio all | grep -Eq "^\s*\S+\s+disabled\s+\S+\s+disabled\s*$" && passing=true
else
	if [ -z "$(find /sys/class/net/ -type d -name 'wireless')" ]; then
		passing=true
	else
		drivers=$(for driverdir in $(find /sys/class/net/* -type d -name 'wireless' | xargs -0 dirname | xargs basename); do basename "$(readlink -f /sys/class/net/"$driverdir"/device/driver/module)";done | sort -u)
		for dm in $drivers; do
			if grep -Eq "^\s*install $dm \/bin\/(true|false)" /etc/modprobe.d/*.conf; then
				passing=true
			fi
		done
	fi
fi

# If the regex matched, output would be generated.  If so, we pass
if [ "$passing" = true ] ; then
	echo "Wireless is disabled"
    exit 0
else
    # print the reason why we are failing
    echo "Wireless is not disabled"
    exit 1
fi