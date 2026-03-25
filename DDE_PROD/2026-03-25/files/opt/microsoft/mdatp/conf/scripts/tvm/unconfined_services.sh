#!/usr/bin/env sh

passing=""

! ps -eZ | grep -q unconfined_service_t && passing=true

# If the test passes, we pass
if [ "$passing" = true ] ; then
	echo "No unconfined services exist"
	exit 0
else
	# print the reason why we are failing
	echo "Unconfined service(s): $(ps -eZ | grep unconfined_service_t) exist"
	exit 1
fi