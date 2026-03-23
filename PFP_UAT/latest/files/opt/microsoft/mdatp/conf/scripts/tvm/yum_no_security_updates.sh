#!/usr/bin/env sh

if yum check-update --security ; then
    exit 0
else
    # print the reason why we are failing
    echo "Security updates are available."
    exit 1
fi