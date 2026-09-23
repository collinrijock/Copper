#!/bin/bash
# Quit the Copper serving WORLD (launched by run.sh). `stop.sh all` quits
# every gauntlet instance. Every builder, critic and smoother runs this when
# its round is over; nobody leaves a browser behind.
#
#   .gauntlet/stop.sh WORLD|all
WORLD="${1:?usage: stop.sh WORLD|all}"
if [ "$WORLD" = all ]; then
    for f in /tmp/copper-*.pid; do [ -e "$f" ] && "$0" "$(basename "$f" .pid | sed 's/^copper-//')"; done
    # Anything launched into a probe world, whatever started it. The user's
    # own Copper has no SEARCH_PROBE in its environment and is left alone.
    for pid in $(pgrep -f "build/Copper.app/Contents/MacOS/Copper"); do
        if ps eww -p "$pid" 2>/dev/null | grep -q "SEARCH_PROBE="; then kill "$pid" 2>/dev/null || true; fi
    done
    exit 0
fi
PID_FILE="/tmp/copper-$WORLD.pid"
if [ -e "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi
# A leftover from before pid files, or one launched by hand.
for pid in $(pgrep -f "build/Copper.app/Contents/MacOS/Copper"); do
    if ps eww -p "$pid" 2>/dev/null | grep -q "SEARCH_PROBE=$WORLD "; then kill "$pid" 2>/dev/null || true; fi
done
sleep 0.3
