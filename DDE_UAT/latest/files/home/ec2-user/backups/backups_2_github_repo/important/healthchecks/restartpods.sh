#!/bin/bash

THRESHOLD=5
LOG_FILE="./logs/restartedpods.log"
DATE=$(date '+%d-%m-%y')

kubectl get pods --no-headers | \
	awk -v threshold=$THRESHOLD '$4 > threshold {print $1, $4}' | \
	while read pod restarts; do
		echo "[$DATE]	Pod: $pod		Restarts: $restarts" >> $LOG_FILE
		kubectl delete pod "$pod"
	done
echo "DONE" >> $LOG_FILE
