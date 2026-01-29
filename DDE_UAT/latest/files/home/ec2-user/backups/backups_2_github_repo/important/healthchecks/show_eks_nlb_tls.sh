#!/bin/bash

kubectl get secret ddedev-vodacom-tls -o jsonpath="{.data['tls\.crt']}" | base64 --decode | openssl x509 -noout -dates > $$_dates

ts_today=$(date +%s)

notBefore=$(cat $$_dates | head -1 | awk -F "=" '{print $2" "$3" "$4" "$5" "$6}')
notAfter=$(cat $$_dates | tail -1 | awk -F "=" '{print $2" "$3" "$4" "$5" "$6}')

ts_notBefore=$(date -d "$notBefore" +%s)
ts_notAfter=$(date -d "$notAfter" +%s)

diff=$((ts_notAfter - ts_today))
days=$((diff / 86400))

s_notBefore=$(echo $notBefore | sed "s/ /#/g")
s_notAfter=$(echo $notAfter | sed "s/ /#/g")

echo "$s_notBefore   $s_notAfter   $days"

rm $$_dates

