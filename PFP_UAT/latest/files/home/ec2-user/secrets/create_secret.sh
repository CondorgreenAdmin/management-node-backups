#!/usr/bin/env bash
set -euo pipefail

# Usage: ./ttt_secret.sh input.txt [secret-name] [namespace]
in_file="${1:-}"
secret_name="${2:-}"
namespace="${3:-default}"

if [[ -z "$in_file" ]]; then
  echo "Usage: $0 input.txt [secret-name] [namespace]" >&2
  exit 1
fi

if [[ ! -f "$in_file" ]]; then
  echo "Input file not found: $in_file" >&2
  exit 1
fi

base_name="$(basename "$in_file")"
default_secret_name="${base_name%.*}"
secret_name="${secret_name:-$default_secret_name}"

out_file="${in_file}_out.yaml"
cat > "$out_file" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
type: Opaque
data:
EOF

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines
  if [[ -z "$line" ]]; then
    continue
  fi

  # Split on first colon
  key="${line%%:*}"
  rest="${line#*:}"

  # If no colon found, skip line
  if [[ "$line" == "$key" ]]; then
    echo "Skipping line without key:value format: $line" >&2
    continue
  fi

  # Trim leading spaces from value
  value="${rest# }"
  encoded="$(printf '%s' "$value" | base64 -w 0)"
  printf '  %s: %s\n' "$key" "$encoded" >> "$out_file"
done < "$in_file"

echo "Wrote base64 output to: $out_file"
