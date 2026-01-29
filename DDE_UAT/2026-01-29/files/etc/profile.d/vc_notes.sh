#
#	Server notes
#
#	Alan Lodewyk
#	2017-10-13
#
#	This script displays the /root/notes.txt
#
gidName=`id -gn`
if [ "$gidName" = "root" ] ; then
	[ -f /root/notes.txt ] && cat /root/notes.txt
fi
