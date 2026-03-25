#!/usr/bin/env bash
#
# usage: ./sp_runtimes.sh your.log
# requires: gawk

gawk '
BEGIN {
  # Ensure mktime/strftime treat times as UTC (your timestamps end with Z)
  ENVIRON["TZ"] = "UTC"
  block = 0
}

# Convert ISO-8601 like 2026-02-20T09:52:37.843152736Z -> nanoseconds since epoch
function iso_to_ns(ts,   y,mo,d,h,mi,s,frac,sec,ns) {
  # strip trailing Z
  sub(/Z$/, "", ts)

  # split date/time
  y  = substr(ts,1,4)
  mo = substr(ts,6,2)
  d  = substr(ts,9,2)
  h  = substr(ts,12,2)
  mi = substr(ts,15,2)

  # seconds + optional fraction
  s = substr(ts,18)              # e.g. "37.843152736" or "37"
  frac = "0"
  if (s ~ /\./) {
    frac = substr(s, index(s,".")+1)
    s = substr(s, 1, index(s,".")-1)
  }

  # pad / trim fraction to 9 digits (nanoseconds)
  frac = frac "000000000"
  frac = substr(frac,1,9)

  # seconds since epoch (UTC)
  sec = mktime(y " " mo " " d " " h " " mi " " s)

  # total nanoseconds
  ns = sec * 1000000000 + frac + 0
  return ns
}

# Format nanoseconds difference as seconds with 3 decimals (ms)
function fmt_ns_diff(dns,   ms) {
  # show milliseconds (3 decimals)
  return sprintf("%.3f", dns / 1000000000.0)
}

# Detect start of a session/block
/ Stored procedures running:/ {
  start_ts = $1
  start_ns = iso_to_ns(start_ts)
  block++
  print "=== Block " block " start " start_ts " ==="
  next
}

# Success lines inside a block
/ success in the DDE stored procedure:/ && block > 0 {
  end_ts = $1
  end_ns = iso_to_ns(end_ts)
  diff_ns = end_ns - start_ns

  # procedure name is after the last colon
  proc = $0
  sub(/^.*stored procedure:[[:space:]]+/, "", proc)

  printf "%s\t%s\t%ss\n", end_ts, proc, fmt_ns_diff(diff_ns)
  next
}
' "$1"
