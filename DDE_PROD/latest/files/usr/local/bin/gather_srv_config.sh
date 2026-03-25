#!/bin/bash
#
#	This Script gathers the server configs and uploads to http://psto101zatcrh.vodacom.corp/srv_config/
#	/usr/local/bin/cfg2html-linux
#
#	2017-11-27
#
[ -f /usr/bin/curl ] || exit
#
curl -o /usr/local/bin/cfg2html-linux http://psto101zatcrh/serverconfigs/cfg2html-linux
chmod +x /usr/local/bin/cfg2html-linux
#
/usr/local/bin/cfg2html-linux -o /tmp
#
UPLOAD_FILE='/tmp/'$(hostname)'.html'
#
#echo "Upload file = "$UPLOAD_FILE
#ls -l $UPLOAD_FILE
#
curl -v -a -X POST --form uploadedfile=@$UPLOAD_FILE http://psto101zatcrh.vodacom.corp/upload_cgi/server_configs_upload.php
