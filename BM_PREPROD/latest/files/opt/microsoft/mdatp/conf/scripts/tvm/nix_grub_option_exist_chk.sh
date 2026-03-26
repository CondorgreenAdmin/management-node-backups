#!/usr/bin/env sh

output="" grubfile="" passing=""

grubfile=$(find /boot -type f \( -name 'grubenv' -o -name 'grub.conf' -o -name 'grub.cfg' \) -exec grep -Pl -- '^\h*(kernelopts=|linux|kernel)' {} \;)

if [ -f "$grubfile" ]; then
	! grep -P -- "^\h*(kernelopts=|linux|kernel).*$" "$grubfile" | grep -Pvq -- "\b$1\b" && passing=true
	output="$(grep -P -- "^\h*(kernelopts=|linux|kernel).*$" "$grubfile" | grep -P -- "\b$1\b")"
fi

# If passing is true we pass
if [ "$passing" = true ] ; then
	echo "PASSED
	\"$grubfile\" contains:
	$output"
	exit 0
else
	# print the reason why we are failing
	echo "FAILED:
	\"$grubfile\" doesn't contain: \"$1\""
	exit 1
fi