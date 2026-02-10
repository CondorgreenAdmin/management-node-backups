#!/bin/sh

#
# Extract configuration from /etc/sysconfig/nfs and write
# environment variables to /run/sysconfig/nfs-utils to be 
# used by the systemd nfs-config service
#

nfs_config=/etc/sysconfig/nfs
if test -r $nfs_config; then
    . $nfs_config
fi

if [ -n "$MOUNTD_PORT" ]; then
	RPCMOUNTDOPTS="$RPCMOUNTDOPTS -p $MOUNTD_PORT"
fi

if [ -n "$STATD_PORT" ]; then
	STATDARG="$STATDARG -p $STATD_PORT"
fi

if [ -n "$STATD_OUTGOING_PORT" ]; then
	STATDARG="$STATDARG -o $STATD_OUTGOING_PORT"
fi

if [ -n "$STATD_HA_CALLOUT" ]; then
	STATDARG="$STATDARG -H $STATD_HA_CALLOUT"
fi

if [ -n "$NFSD_V4_GRACE" ]; then
	grace="-G $NFSD_V4_GRACE"
fi

if [ -n "$NFSD_V4_LEASE" ]; then
	lease="-L $NFSD_V4_LEASE"
fi

if [ -n "$RPCNFSDCOUNT" ]; then
    nfsds=$RPCNFSDCOUNT
else
    nfsds=8
fi

if [ -n "$RPCNFSDARGS" ]; then
	nfsdargs="$RPCNFSDARGS $grace $lease $nfsds"
else
	nfsdargs="$grace $lease $nfsds"
fi

mkdir -p /run/sysconfig
{
echo RPCNFSDARGS=\"$nfsdargs\"
echo RPCMOUNTDARGS=\"$RPCMOUNTDOPTS\"
echo STATDARGS=\"$STATDARG\"
echo SMNOTIFYARGS=\"$SMNOTIFYARGS\"
echo RPCIDMAPDARGS=\"$RPCIDMAPDARGS\"
echo GSSDARGS=\"$RPCGSSDARGS\"
echo BLKMAPDARGS=\"$BLKMAPDARGS\"
echo GSS_USE_PROXY=\"$GSS_USE_PROXY\"
} > /run/sysconfig/nfs-utils
