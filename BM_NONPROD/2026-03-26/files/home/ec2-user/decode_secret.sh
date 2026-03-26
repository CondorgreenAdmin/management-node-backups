#!/bin/bash

SECRET_NAME=$1
NAMESPACE=$2

if [ -z "$SECRET_NAME" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <secret-name> <namespace>"
  exit 1
fi

kubectl get secret $SECRET_NAME -n $NAMESPACE -o json | jq -r '.data | to_entries[] | "\(.key): \(.value)"' | while IFS=: read -r key value; do
  echo "$key: $(echo $value | base64 --decode)"
done

