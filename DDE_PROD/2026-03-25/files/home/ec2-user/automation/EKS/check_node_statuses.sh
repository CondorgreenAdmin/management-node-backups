 #!/bin/bash

cd ~/automation/EKS

export PATH=/usr/local/bin:/usr/bin:/bin

DTE=$(date +'%Y%m%d_%H%M%S')

nodes=$(kubectl get nodes --no-headers | awk '{print $1,$2}')

nodeStatus=($(kubectl get nodes --no-headers | awk '{print $1":"$2}'))

# Populate the master file
for node in "${nodeStatus[@]}"; do
        if grep -q "${node}" master; then
                # echo "${node} exists in master"
                :
        else
                #echo "${node} does not exists in master - adding it"
                echo "${node}:NotSent" >> master
        fi
done

DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)
#DL="$DL, michael.dirks@condorgreen.com, arnulf.hanauer@condorgreen.com"
#DL="michaelalex.dirks@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

# Check if status is not ready from master file
while IFS=: read -r node status alert; do
        echo "Node: $node, Status: $status, Alert: $alert"
        if [ "$status" != "Ready" ] && [ "$alert" = "NotSent" ]; then
                if [ -z "$node" ] || [ -z "$status" ]; then
                        # echo "Did not find a node name or node status" >> $logfile
                        :
                else
                        aws ec2 get-console-output \
                                --instance-id $(aws ec2 describe-instances --filters "Name=private-dns-name,Values=${node}" --query "Reservations[].Instances[].InstanceId" --output text) \
                                --latest \
                                --output text > ./logs/instance_console_logs/${DTE}_${node}_console.log
			echo "Sending email alert"
                        echo -e "Hi,\n\nIf you are recieving this then it means that a Production DDE EKS node is not in the ready state. \nNode: $node\nStatus: $status\n\nNOTE: \n\nKind regards,\nPlatform" | mutt -s "PROD DDE EKS NODE FAILURE" -a ./logs/instance_console_logs/${DTE}_${node}_console.log -- $DL
                        # Change master file
                        sed -i 's/\(.*:.*:\)NotSent$/\1Sent/' master
                fi
        fi
done < master

# Clean up. Check if node exists on aws. If not then remove from master
while IFS=: read -r node status alert; do
        instanceId=$(aws ec2 get-console-output \
                --instance-id $(aws ec2 describe-instances --filters "Name=private-dns-name,Values=${node}" --query "Reservations[].Instances[].InstanceId" --output text) \
                --output text)
        if [ -n "$instanceId" ]; then
                echo "Node exists"
                :
        else
                echo "Node does not exist. Will remove from master file"
                sed -i '/${node}/d' master
        fi
done < master

