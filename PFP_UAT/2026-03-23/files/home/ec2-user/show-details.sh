#!/bin/bash
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#







seclist=$(kubectl get secrets | egrep -v "NAME|tls" | awk '{print $1}')

for nam in $seclist
do
	echo $nam
	echo "=============================="
	./decode-secret.sh $nam default
	echo
	echo
done



#NAME                    TYPE                DATA   AGE
#aws-secret              Opaque              5      3d10h
#fmw-secret              Opaque              8      23d
#general-config-secret   Opaque              10     25d
#google-maps-secret      Opaque              2      25d
#jwt-secret              Opaque              5      25d
#mysql-secret            Opaque              6      25d
#oauth-secret            Opaque              9      25d
#tls                     kubernetes.io/tls   2      19d
#uim-secret              Opaque              8      23d
#vumatel-secret          Opaque              4      25d

