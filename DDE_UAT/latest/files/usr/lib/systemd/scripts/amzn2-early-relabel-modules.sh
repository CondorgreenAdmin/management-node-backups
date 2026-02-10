#!/bin/bash
 
# If systemd is explicitly disabled, we know relabeling
# will not succeed, so exit early.
if [ -r /sys/fs/selinux/enforce ]; then
  if [ "$(</sys/fs/selinux/enforce)" = "0" ]; then
     exit 0
  fi
fi
 
/sbin/restorecon -R /lib/modules
exit $?
