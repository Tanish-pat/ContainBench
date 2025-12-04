#!/usr/bin/env bash
set -euo pipefail

ENGINES=("docker" "podman")
WORKLOADS=("web" "micro" "db")
LOGROOT="data"
ERROR_REPORT="${LOGROOT}/error_report.txt"

mkdir -p "$LOGROOT"

# deploy engines first
echo "Starting container engines..."
./scripts/deploy_docker_rootless.sh
./scripts/deploy_podman.sh

echo "Engines deployed."

# loop through workloads
for ENGINE in "${ENGINES[@]}"; do
    for WORKLOAD in "${WORKLOADS[@]}"; do
        echo "Running benchmark for ${WORKLOAD} on ${ENGINE}..."
        ./scripts/run_benchmarks.sh "$ENGINE" "$WORKLOAD"

        echo "Collecting metrics for ${WORKLOAD} on ${ENGINE}..."
        ./scripts/collect_metrics.sh "$ENGINE" "$WORKLOAD"

        echo "Measuring energy for ${WORKLOAD} on ${ENGINE}..."
        sudo ./scripts/energy_measure.sh "$ENGINE" "$WORKLOAD"

        echo "Running security probe for ${ENGINE}..."
        ./scripts/security_probe.sh "$ENGINE"

        echo "---------------------------------------------"
    done
done
echo "All benchmarks, metrics, energy, and security tests complete."
echo "Executing post-run anomaly scan..."

> "$ERROR_REPORT"

find "$LOGROOT" -type f -name "*.log" | while read -r LOG; do
    # Only match lines not starting with [INFO] or [PASS]
    grep -Ei "fail|error|fatal|panic|denied|refused|timeout" "$LOG" \
        | grep -Ev "^\[INFO\]|\[PASS\]" \
        > /tmp/tmp_error_lines.txt

    if [ -s /tmp/tmp_error_lines.txt ]; then
        {
            echo "-----"
            echo "FILE: $LOG"
            cat /tmp/tmp_error_lines.txt
        } >> "$ERROR_REPORT"
    fi
done

if [ -s "$ERROR_REPORT" ]; then
    echo "Pipeline Health: DEGRADED"
    echo "Error summary available at ${ERROR_REPORT}"
    exit 2
else
    rm -f "$ERROR_REPORT"
    echo "Pipeline Health: OPTIMAL"
fi

echo "All benchmarks, metrics, energy, and security tests complete."