#!/bin/bash

# Define your cluster and node group names
CLUSTER_NAME="dev-dde-eks-cluster-3"
#NODEGROUP_NAME="dev-dde-nodegroup-3" # original node group (AL2)
NODEGROUP_NAME="uat-dde-eks-nodegroup-br" # New bottlerocket node group

# Get the Auto Scaling Group name
ASG_NAME=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP_NAME | jq -r '.nodegroup.resources.autoScalingGroups[].name')

# Get the instance IDs in the Auto Scaling Group
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME | jq -r '.AutoScalingGroups[].Instances[].InstanceId')

# Describe the EC2 instances to get their statuses
###aws ec2 describe-instances --instance-ids $INSTANCE_IDS | jq '.Reservations[].Instances[] | {InstanceId: .InstanceId, State: .State.Name}'
aws ec2 describe-instances --instance-ids $INSTANCE_IDS | egrep -A 3 -i "instanceid|\"State\": {" | egrep "InstanceId|Name" | sed "s/,//g" | sed "s/\"//g" | awk '{a=$2;getline;print "eks-node_"a,$2}'

