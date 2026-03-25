#!/bin/bash

CRED_FILE="$HOME/.aws/credentials"

# Extract all profile names (lines starting with [profile])
grep '^\[' "$CRED_FILE" | sed 's/^\[\(.*\)\]$/\1/' | while read -r profile; do
    aws s3 ls --profile "$profile"
done

