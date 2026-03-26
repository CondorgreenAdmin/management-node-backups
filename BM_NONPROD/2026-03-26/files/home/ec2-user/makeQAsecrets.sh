#!/bin/bash

INFILE=UATsecrets
OUTFILE=QAsecrets
touch $OUTFILE;rm $OUTFILE

while read a b c d e
do
   #./decode_secret.sh $b $a | awk -v NAM=$b -v NS=$a '{print NS,NAM,"   ",$0}' >> $OUTFILE
   NS=$(echo $a | sed "s/uat-/qa-/g")
   echo -n "kubectl create secret generic $b -n $NS " >> $OUTFILE
   ./decode_secret.sh $b $a | awk -v NAM=$b -v NS=$a '{printf "%s%s%s%s ", "--from-literal=",substr($1,1,length($1)-1),"=",$2}' >> $OUTFILE
   echo >> $OUTFILE
done < $INFILE
echo

cat $OUTFILE



#echo "Example looked like"
#echo kubectl create secret generic document-management-wcc-secret -n qa-beyond-mobile --from-literal=UPLOAD_URL="<wcc-upload-url>" --from-literal=RETRIEVE_URL="<wcc-retrieve-url>" 
#echo --from-literal=USERNAME="<wcc-username>" --from-literal=PASSWORD="<wcc-password>"
