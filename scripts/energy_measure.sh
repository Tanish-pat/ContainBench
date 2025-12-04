#!/usr/bin/env bash
set -e

ENGINE=$1
WORKLOAD=$2
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUT="data/energy-${ENGINE}-${WORKLOAD}/${TIMESTAMP}.log"

echo "ENGINE: $ENGINE"           > "$OUT"
echo "WORKLOAD: $WORKLOAD"      >> "$OUT"
echo "START: $(date --iso-8601=seconds)" >> "$OUT"

DURATION=30  # 30-second sampling window

# Detect available perf events
AVAILABLE_EVENTS=$(sudo perf list | grep -E "cpu-cycles|instructions")

if command -v perf >/dev/null 2>&1 && [ -n "$AVAILABLE_EVENTS" ]; then
    {
        echo "USING: perf stat"
        echo "DURATION: ${DURATION}s"
    } >> "$OUT"

    # Run perf with available events
    sudo perf stat -a -I 1000 -e cpu-cycles -e instructions sleep $DURATION >>"$OUT" 2>&1 &

    PERF_PID=$!
    echo "perf PID: $PERF_PID" >> "$OUT"

    wait $PERF_PID || true
else
    {
        echo "perf unavailable or no hardware counters"
        echo "DURATION: ${DURATION}s"
        echo "Dumping /sys/class/powercap/*/energy_uj (if available)"
    } >> "$OUT"

    START=$(date +%s)
    END=$((START + DURATION))

    while [ "$(date +%s)" -lt "$END" ]; do
        echo "--- SAMPLE $(date --iso-8601=seconds) ---" >> "$OUT"
        if [ -d /sys/class/powercap ]; then
            for f in /sys/class/powercap/*/energy_uj; do
                echo "$f: $(cat "$f" 2>/dev/null)" >> "$OUT"
            done
        else
            echo "No energy counters available on this host" >> "$OUT"
        fi
        sleep 1
    done
fi

echo "END: $(date --iso-8601=seconds)" >> "$OUT"
echo "Energy metrics complete."