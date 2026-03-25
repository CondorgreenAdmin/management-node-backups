#!//bin/bash
# keepalive.sh – send a tiny, almost invisible "poke" to the terminal
# every 4 minutes to keep the session from being considered idle.

INTERVAL_SECONDS=240   # 4 minutes

while true; do
  if [ -w /dev/tty ]; then
    # Backspace + space + backspace: causes minimal visual change
    # but still counts as activity on the session.
    printf ' \b \b' > /dev/tty
  fi
  sleep "$INTERVAL_SECONDS"
done
