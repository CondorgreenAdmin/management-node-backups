#!/bin/bash
#
#   Script to
#      1. create the User Audit HTML output
#      2. Curl to psto101zatcrh - Website
#      3. Curl to psto101zatcrh - Email
#
[ -f /usr/bin/curl ] || exit
#
export http_proxy=""
export FTP_PROXY=""
export ftp_proxy=""
export no_proxy=""
export HTTP_PROXY=""
#
curl -k -o /usr/local/bin/useraudit.pl https://psto101zatcrh/useraudits/.prog/useraudit.pl
chmod +x /usr/local/bin/useraudit.pl
#
[ -d /root/User_Audits ] || mkdir /root/User_Audits
#
USER_AUDIT_DIR="/root/User_Audits"
OUTPUT_FILE="$USER_AUDIT_DIR/$(hostname)_User_Audit.html"
OUTPUT_FILE_DATE="$USER_AUDIT_DIR/$(hostname)_User_Audit_$(date +%Y-%m-%d).html"
#
/usr/local/bin/useraudit.pl -report > $OUTPUT_FILE_DATE
ls -l $OUTPUT_FILE_DATE
cp $OUTPUT_FILE_DATE $OUTPUT_FILE
#
#
#echo "Upload file = "$OUTPUT_FILE
#ls -l $UPLOAD_FILE
#
# Curl to psto101zatch
#
curl -k -v -a POST --form uploadedfile=@$OUTPUT_FILE https://psto101zatcrh.vodacom.corp/upload_cgi/useraudit_upload.php
#
# Email to Sharepoint
#
curl -k -v -a POST --form uploadedfile=@$OUTPUT_FILE_DATE https://psto101zatcrh.vodacom.corp/upload_cgi/useraudit_email.php
#
mv $OUTPUT_FILE_DATE $OUTPUT_FILE
