#!/usr/bin/env sh

l_output=""
l_rpcv="$(sudo -Hiu root env | awk -F= '/^PATH=/{print $2}')"
grep -q '::' <<< "$l_rpcv" && l_output="$l_output\n - root's path contains a empty directory \"::\""
grep -Eq ':\s*$' <<< "$l_rpcv" && l_output="$l_output\n - root's path contains a trailing \":\""

for l_dir in $(tr ":" " " <<< "$l_rpcv") ; do
   if [ "$l_dir" = "." ] ; then
      l_output="$l_output\n - root's PATH contains current working directory \".\""
   elif [ -d "$l_dir" ] ; then
      [ "$(stat -Lc "%U" "$l_dir")" != "root" ] && l_output="$l_output\n - root doesn't own directory \"$l_dir\" in its path"
      stat -Lc "%a" "$l_dir" | grep -Eq '[0-7][7,3,2][0-7]' && l_output="$l_output\n - root's path contains group writable directory \"$l_dir\""
      stat -Lc "%a" "$l_dir" | grep -Eq '[0-7][0-7][7,3,2]' && l_output="$l_output\n - root's path contains world writable directory \"$l_dir\""
   fi
done

# If all tests pass, passing will be true, and we pass
if [ -z "$l_output" ]; then
   echo -e "\n- Audit Result:\n  ** PASS **\n"
   exit 0
else
   # print the reason why we are failing
   echo -e "\n- Audit Result:\n  ** FAIL **\n - Reason(s) for audit failure:\n$l_output\n"
   exit 1
fi