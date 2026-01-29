#!/usr/bin/env sh

passing="" output="" output2="" output3=""

if [ -e "$1" ]; then
   if stat -Lc "%a" "$1" | grep -Eq '[640][40][40]'; then
      passing=true
   else
      passing=false && output="File: \"$(readlink -f "$1")\" has permissions: \"$(stat -Lc "%a" "$1")\""
   fi

   if [ "$(stat -Lc "%u" "$1")" = 0 ]; then
      [ "$passing" != false ] && passing=true
   else
      passing=false && output2="File: \"$(readlink -f "$1")\" is owned by \"$(stat -Lc "%U" "$1")\""
   fi

   if [ "$(stat -Lc "%g" "$1")" = 0 ]; then
      [ "$passing" != false ] && passing=true
   else
      passing=false && output3="File: \"$(readlink -f "$1")\" belongs to group  \"$(stat -Lc "%G" "$1")\""
   fi
fi


# If passing is true, we pass
if [ "$passing" = true ] ; then
   echo "PASSED!"
   exit 0
else
   # print the reason why we are failing
   echo "FAILED!"
   [ -n "$output" ] && echo "$output"
   [ -n "$output2" ] && echo "$output2"
   [ -n "$output3" ] && echo "$output3"
   exit 1
fi