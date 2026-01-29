#
#       Session timeout
#
#       Alan Lodewyk
#       2017-10-13
#
#
uidName=`id -un`
if [ "$uidName" = "root" ] ; then
   TMOUT=300
   readonly TMOUT
else
   TMOUT=2400
   #readonly TMOUT
fi
#
export TMOUT
