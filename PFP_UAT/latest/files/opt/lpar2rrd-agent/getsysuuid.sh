#!/bin/sh

#
# for Linux x86 platform only
# script gets UUID, it works only under root user
# it runs only after a reboot, from systemd lpar2rrd-agent service
#

if [ -f /sys/class/dmi/id/product_uuid ]; then
  uuid=`cat /sys/class/dmi/id/product_uuid`
else
  if [ -f /usr/sbin/dmidecode ]; then
    uuid=`/usr/sbin/dmidecode 2>/dev/null| grep UUID | head -1 | sed 's/.* //'`
  else
    if [ -f /usr/bin/lshal ]; then
      uuid=`/usr/bin/lshal 2>/dev/null|grep -i system.hardware.uuid| cut -d "'" -f 2`
    else
      if [ -f /sys/hypervisor/uuid ]; then
        uuid=`cat /sys/hypervisor/uuid 2>/dev/null`
      fi
    fi
  fi
fi

if [ ! "$uuid"x = "x" ]; then
  # save UUID to ge readable for LPAR2RRD user
  echo "LPAR2RRD: UUID is $uuid, saving it in /opt/lpar2rrd-agent/.uuid"
  echo "$uuid" > /opt/lpar2rrd-agent/.uuid 
  chmod 444 /opt/lpar2rrd-agent/.uuid 
else
  echo "LPAR2RRD ERROR: UUID has not been found"
fi

