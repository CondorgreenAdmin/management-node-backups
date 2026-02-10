#!/bin/sh +x
#
# kabi.sh - Automatically extract any kernel symbol checksum from the
#           symvers file and add to RPM deps.  This is used to move the
#           checksum checking from modprobe to rpm install for 3rd party
#           modules (so they can fail during install and not at load).

IFS=$'\n'

for symvers in $(grep -E '/boot/symvers-*') $*;
do
    zcat $symvers | awk ' {print "kernel(" $2 ") = " $1 }'
done
