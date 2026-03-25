#!//bin/bash
#set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <short-name> [extra kubectl logs args...]"
  echo "Example: $0 dde -f"
  exit 1
fi

SHORT_NAME="$1"
shift  # shift so that $@ now holds any extra args (e.g. -f, container, etc.)
# Find the first pod whose name starts with "<SHORT_NAME>-depl"

POD_NAME=$(kubectl get pods \
  --no-headers \
  -o custom-columns=":metadata.name" \
  | egrep "^${SHORT_NAME}-depl" \
  | head -n 1)

#ln=$(echo $POD_NAME | wc -w)

#echo "Len=$ln"
#echo "POD Name -> $POD_NAME"

if [ -z "${POD_NAME}" ]; then
  echo "No pod found matching prefix '${SHORT_NAME}-depl'"
  exit 1
fi
echo "Showing logs for pod: ${POD_NAME}"

kubectl logs "${POD_NAME}" "$@" -f --timestamps
