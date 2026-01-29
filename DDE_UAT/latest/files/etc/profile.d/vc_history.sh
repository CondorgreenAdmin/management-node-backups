#
#	Session History Setup 
#
#	Alan Lodewyk
#	2017-10-13
#
#	If individual history file are required see line below
#	export HISTFILE=/opt/.sh_history/root_history-$(who am i | awk '{print $1}';exit)
#
gidName=`id -gn`
if [ "$gidName" = "root" ] ; then
#	shopt -s histappend
	export HISTCONTROL
	export HISTSIZE=10000
	export HISTTIMEFORMAT="%F %T - "
	export PROMPT_COMMAND='history -a'
	export HISTIGNORE='uname:whoami'

fi
