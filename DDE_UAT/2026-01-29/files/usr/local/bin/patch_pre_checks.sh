#!/bin/bash
# pre patch health check 
# Zayde James 28 Nov 2017

# df all filesystems, cdrom, and print %
echo " "
echo "---------------------------------------------------------------------------"
echo " "
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
  echo $output
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 80 ]; then                                                        #if % used is more that 80%
    echo "Running out of space \"$partition ($usep%)\" on $(hostname) as on $(date)" 
     #mail -s "Alert: Almost out of disk space $usep%" systemsupportlinux@vodacom.co.za
  fi
done

#cpu check in %
echo " "
#grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'
top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}' 

#memory check
echo " "
free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
echo " "
echo "----------------------------------------------------------------------------"
echo " "
