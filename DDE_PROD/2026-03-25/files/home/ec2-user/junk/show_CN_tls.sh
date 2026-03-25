#!/bin/bash

REGION=af-south-1
F2=$REGION-bundle.pem

echo "EKS NLB certificate: "`kubectl get secret dde-vodacom-tls -o jsonpath="{.data['tls\.crt']}" | base64 --decode | openssl x509 -noout -dates -subject`

CN=$(wget https://truststore.pki.rds.amazonaws.com/$REGION/$F2 2>/dev/null)

echo "RDS certificate: "`openssl x509 -in $F2 -noout -dates -subject`

#keytool -printcert -v -file $F2 | egrep "Owner:|Issuer:|Serial number:|Valid from:"

rm $F2

