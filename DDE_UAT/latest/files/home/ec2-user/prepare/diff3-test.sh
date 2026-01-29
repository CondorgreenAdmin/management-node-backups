#!/usr/bin/bash

#TODO=$(./create-uat-list.sh)
#for nam in $TODO
#do
#   diff -u -w -B uat_$nam prod_$nam
#   echo "================================================================================"
#   echo
#done



set -euo pipefail
 
# three_way_proc_diff.sh
# Show precise, git-like block differences among three SQL files:
#   LEFT (db1), BASE (db2), RIGHT (db3).
# Strategy:
#   - Normalize whitespace (tabs->spaces, collapse spaces, trim ends)
#   - If git is available => render a combined three-way diff (git --cc)
#   - Else => show two unified diffs vs BASE (LEFT vs BASE, RIGHT vs BASE)
#
# Usage:
#   three_way_proc_diff.sh [-c N] [-l "LBL1,BASE,LBL3"] LEFT.sql BASE.sql RIGHT.sql
#
# Examples:
#   three_way_proc_diff.sh db1_proc.sql db2_proc.sql db3_proc.sql
#   three_way_proc_diff.sh -c 2 -l "DB1,BASE,DB3" db1.sql db2.sql db3.sql
#
# Notes:
# - Whitespace is normalized before diffing (so indent/spacing don't show).
# - Default context is 2 lines.
# - Labels are optional and only affect headers.
 
CTX=2
LABELS="LEFT,BASE,RIGHT"
 
while getopts ":c:l:" opt; do
  case "$opt" in
    c) CTX="${OPTARG}";;
    l) LABELS="${OPTARG}";;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 2;;
    :)  echo "Option -$OPTARG requires an argument." >&2; exit 2;;
  esac
done
shift $((OPTIND-1))
 
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 [-c N] [-l \"LBL1,BASE,LBL3\"] LEFT BASE RIGHT" >&2
  exit 2
fi
 
FILE_LEFT="$1"; FILE_BASE="$2"; FILE_RIGHT="$3"
IFS=',' read -r L1 L2 L3 <<< "$LABELS"
 
for f in "$FILE_LEFT" "$FILE_BASE" "$FILE_RIGHT"; do
  [ -f "$f" ] || { echo "Error: file not found: $f" >&2; exit 1; }
done
 
# Normalize whitespace but preserve line structure
norm_copy() {
  local in="$1" out="$2"
  awk '
    {
      gsub(/\t/, " ");      # tabs -> spaces
      gsub(/  +/, " ");     # collapse runs of spaces
      sub(/^ +/, "");       # trim leading
      sub(/ +$/, "");       # trim trailing
      print
    }
  ' "$in" > "$out"
}
 
# Temp workspace
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
tL="$work/left.sql"; tB="$work/base.sql"; tR="$work/right.sql"
norm_copy "$FILE_LEFT"  "$tL"
norm_copy "$FILE_BASE"  "$tB"
norm_copy "$FILE_RIGHT" "$tR"
 
have_git=0
#command -v git >/dev/null 2>&1 || have_git=0
 
if [ $have_git -eq 1 ]; then
  # --- Git combined diff path ---
  repo="$work/repo"
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -q
    # avoid identity prompts
    git config user.name "three-way-diff"
    git config user.email "noreply@example.com"
 
    # Commit BASE
    cp "$tB" proc.sql
    git add proc.sql
    git commit -q -m "BASE"
 
    # Branch for LEFT
    git checkout -q -b left
    cp "$tL" proc.sql
    git commit -q -am "LEFT"
 
    # Branch for RIGHT (from BASE)
    git checkout -q main
    git checkout -q -b right
    cp "$tR" proc.sql
    git commit -q -am "RIGHT"
 
    # Attempt a no-commit merge to create an index with stages 1/2/3
    set +e
    git checkout -q right
    git merge -q --no-commit --no-ff left >/dev/null 2>&1
    merge_rc=$?
    set -e
 
    # If merge had conflicts (common case when things differ in same areas),
    # the index now holds the three stages; --cc prints a combined hunk view.
    if [ $merge_rc -ne 0 ]; then
      echo "=== Combined three-way diff (${L1} vs ${L2} vs ${L3}) ==="
      # -w ignore whitespace, -U$CTX sets context lines
      # diff.compactionHeuristic makes hunks a bit nicer (optional).
      git -c diff.compactionHeuristic=true diff -w --cc -U"$CTX"
      exit 0
    else
      # If merge auto-resolved with no conflicts, show side-by-side parents.
      # This still gives concise hunks for both sides relative to BASE.
      echo "=== ${L1} vs ${L2} (unified, context=${CTX}) ==="
      git diff -w -U"$CTX" HEAD^ HEAD -- proc.sql
      echo
      echo "=== ${L3} vs ${L2} (unified, context=${CTX}) ==="
      # Show diff between RIGHT and BASE commit:
      # main was BASE; so compare right^ (BASE) .. right (RIGHT)
      git checkout -q right
      git diff -w -U"$CTX" HEAD^ HEAD -- proc.sql
      exit 0
    fi
  )
else
  # --- Fallback: two unified diffs vs BASE (no Git needed) ---
  echo "=== ${L1} vs ${L2} (unified, context=${CTX}) ==="
  # Use diff -u with context; many diff implementations accept -U N
  # If your diff lacks -w, we already normalized whitespace.
  if diff -u -U "$CTX" "$tB" "$tL"; then
    echo "(no differences)"
  fi
  echo
  echo "=== ${L3} vs ${L2} (unified, context=${CTX}) ==="
  if diff -u -U "$CTX" "$tB" "$tR"; then
    echo "(no differences)"
  fi
fi
