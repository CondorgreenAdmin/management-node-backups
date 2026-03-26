#!/bin/bash


aws ecr describe-repositories

while read junk
do
   echo "Creating $junk"
   aws ecr create-repository --repository-name $junk --image-scanning-configuration scanOnPush=true --encryption-configuration encryptionType=KMS,kmsKey="arn:aws:kms:af-south-1:396913725884:key/a0841810-c6b3-4d71-aaaa-72d123ba5b62"
done<ecr.txt


aws ecr describe-repositories



