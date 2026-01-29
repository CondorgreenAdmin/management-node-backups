#!/bin/bash

GROUP="DOPA-DDE:CBUIT:Appl:ZA:UAT"
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
SYS="DDE"
ENV="dev"

yesTags=false
tagList=""

PI=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId]" --output=text)
PV=$(aws ec2 describe-volumes --query "Volumes[*].VolumeId" --output=text)
ASG=$(aws autoscaling describe-auto-scaling-groups --output json | grep AutoScalingGroupName | awk -F "\"" '{print $4}')
LB=$(aws elbv2 describe-load-balancers --query "LoadBalancers[*].{Name:LoadBalancerName,Type:Type}" --output=text | awk '{print $1}')
SG=$(aws ec2 describe-security-groups --query "SecurityGroups[*].{ID:GroupId,Name:GroupName}" --output=text | awk '{print $1}')
S3=$(aws s3api list-buckets --query "Buckets[*].Name" --output=text)
RDSCLUSTERS=$(aws rds describe-db-clusters --query "DBClusters[*].DBClusterArn" --output=text)  ### Covers both RDS & DOCDB
RDSINSTANCES=$(aws rds describe-db-instances --query "DBInstances[*].DBInstanceArn" --output=text)   ### Covers both RDS & DOCDB
RDS=$(echo "$RDSCLUSTERS $RDSINSTANCES")

for RESOURCE in $PI
do
   echo -n "$RESOURCE  "
   CNT=$(aws ec2 describe-instances --instance-ids $RESOURCE --query "Reservations[].Instances[].[InstanceId, Tags]" --output text | awk '{print $1}'| egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      "We need tags"
      yesTags=true
      tagType="EC2-Instance"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws ec2 create-tags --resources "$RESOURCE" --tags Key="Project",Value="$SYS" Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za" Key="Confidentiality",Value="C3" Key="SecurityZone",Value="A" Key="TaggingVersion",Value="V2.0" Key="BusinessService",Value="$GROUP" Key="Environment",Value="$ENV"
   fi
   echo
done

for RESOURCE in $PV
do
   echo -n "$RESOURCE  "
   #CNT=$(aws ec2 describe-volumes --volume-ids $RESOURCE --query "Volumes[*].Tags" --output json | grep Key | wc -l)
   CNT=$(aws ec2 describe-volumes --volume-ids $RESOURCE --query "Volumes[*].Tags" --output text | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="EC2-Volume"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws ec2 create-tags --resources "$RESOURCE" --tags Key="Project",Value="$SYS" Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za" Key="Confidentiality",Value="C3" Key="SecurityZone",Value="A" Key="TaggingVersion",Value="v2.0" Key="BusinessService",Value="$GROUP" Key="Environment",Value="$ENV"
   fi
   echo
done

for RESOURCE in $ASG
do
   echo -n "$RESOURCE  "
   CNT=$(aws autoscaling describe-tags --filters "Name=auto-scaling-group,Values=$RESOURCE" --output text | awk '{print $2}' | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="AutoScalingGroup"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws autoscaling create-or-update-tags --tags \
         Key="Project",Value=$SYS,PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za",PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="Confidentiality",Value="C3",PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="SecurityZone",Value="D",PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="TaggingVersion",Value="V2.0",PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="BusinessService",Value=$GROUP,PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group \
         Key="Environment",Value=$ENV,PropagateAtLaunch=true,ResourceId=$RESOURCE,ResourceType=auto-scaling-group 
   fi
   echo
done

for RESOURCE in $LB
do
   LBARN=$(aws elbv2 describe-load-balancers --names $RESOURCE --query "LoadBalancers[0].LoadBalancerArn" --output text)
   echo -n "$RESOURCE  "
   CNT=$(aws elbv2 describe-tags --resource-arns $LBARN --output=text | awk '{print $2}' | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="LoadBalancer"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws elbv2 add-tags --resource-arns $LBARN --tags \
         Key="Project",Value="$SYS" Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za" Key="Confidentiality",Value="C3" Key="SecurityZone",Value="A" Key="TaggingVersion",Value="v2.0" Key="BusinessService",Value="$GROUP" Key="Environment",Value="$ENV"
   fi
   echo
done

for RESOURCE in $SG
do
   echo -n "$RESOURCE  "
   CNT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$RESOURCE" --output=text | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="SECURITY_GROUP"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws ec2 create-tags --resources "$RESOURCE" --tags Key="Project",Value="$SYS" Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za" Key="Confidentiality",Value="C3" Key="SecurityZone",Value="A" Key="TaggingVersion",Value="v2.0" Key="BusinessService",Value="$GROUP" Key="Environment",Value="$ENV"
   fi
   echo
done

for RESOURCE in $S3
do
   echo -n "$RESOURCE  "
   CNT=$(aws s3api get-bucket-tagging --bucket "$RESOURCE" --output=text | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="S3_BUCKET"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws s3api put-bucket-tagging --bucket "$RESOURCE" --tagging 'TagSet=[{Key="Project",Value="'$SYS'"},{Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za"},{Key="Confidentiality",Value="C3"},{Key="SecurityZone",Value="A"},{Key="TaggingVersion",Value="v2.0"},{Key="BusinessService",Value="'$GROUP'"},{Key="Environment",Value="'$ENV'"}]'
   fi
   echo
done

for RESOURCE in $RDS   ###handles both RDS/DOCDB Cluster/Instances - 4x different things
do
   echo -n "$RESOURCE  "
   CNT=$(aws rds list-tags-for-resource --resource-name "$RESOURCE" --output=text | egrep -i "Project|ManagedBy|Confidentiality|SecurityZone|TaggingVersion|BusinessService|Environment" | wc -l )
   echo $CNT
   if [[ $CNT < 7 ]];then
      echo "We need tags"
      yesTags=true
      tagType="RDS_CLUSTER_INSTANCE"
      tagList="$tagList $tagType=$RESOURCE \n"
      aws rds add-tags-to-resource --resource-name "$RESOURCE" --tags Key="Project",Value="$SYS" Key="ManagedBy",Value="arnulf.hanauer@vcontractor.co.za" Key="Confidentiality",Value="C3" Key="SecurityZone",Value="D1" Key="TaggingVersion",Value="v2.0" Key="BusinessService",Value="$GROUP" Key="Environment",Value="$ENV"
   fi
   echo
done


if [[ $yesTags == true ]];then
   echo -e "TAG updates were required in the $SYS $ENV environment for\n\n$tagList" | mutt -s "$SYS NONPROD(UAT) TAGGING" -- $DL
fi



