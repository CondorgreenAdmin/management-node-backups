#!/usr/bin/env sh

passing="" test1="" test2="" output="" output2=""

if command -v apparmor_status >/dev/null; then
   pem=$(apparmor_status | awk '(/profiles are in enforce\s+mode/) {print $1}')
   pcm=$(apparmor_status | awk '(/profiles are in complain\s+mode/) {print $1}')
   apl=$(apparmor_status | awk '/ profiles are loaded/ {print $1}')
   apuc=$(apparmor_status | awk '/processes are unconfined but have a profile defined/ {print $1}')
   ngp=$((pcm+pem))
   if [ "$apl" -gt 0 ]; then
      [ "$apuc" = 0 ] && test1=passed || output="$apuc processes are unconfined but have a profile defined"
      if [ "$1" = complain ]; then
         [ "$ngp" = "$apl" ] && test2=passed || output2="Not all profiles are in complain or enforcing mode"
      elif [ "$1" = enforce ]; then
         [ "$pem" = "$apl" ] && test2=passed || output2="Not all profiles are in enforcing mode"
      fi
   else
      output2="No profiles are loaded"
   fi
   [ "$test1" = passed ] && [ "$test2" = passed ] && passing=true
else
   output="Command apparmor_status doesnt exist. Confirm AppArmor is installed"
fi


# If passing is true, we pass
if [ "$passing" = true ] ; then
   echo "PASSED! All AppArmor Profiles are in correct mode"
   exit 0
else
   # print the reason why we are failing
   echo "FAILED!"
   [ -n "$output" ] && echo "$output"
   [ -n "$output2" ] && echo "$output2"
   exit 1
fi