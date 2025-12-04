#!/usr/bin/env bash
set -e

ENGINES=("docker" "podman")
WORKLOADS=("web" "micro" "db")

# Cleanup old images
echo "Cleaning up old images..."
for ENGINE in "${ENGINES[@]}"; do
    for WORKLOAD in "${WORKLOADS[@]}"; do
        if $ENGINE images -q "${WORKLOAD}:latest" &>/dev/null; then
            echo "Removing ${WORKLOAD}:latest from $ENGINE..."
            $ENGINE rmi -f "${WORKLOAD}:latest" || true
        fi
    done
done
echo "Cleanup complete."
echo

# Build all images sequentially
count=1
for ENGINE in "${ENGINES[@]}"; do
    for WORKLOAD in "${WORKLOADS[@]}"; do
        echo "[$count] Building $WORKLOAD image for $ENGINE..."
        $ENGINE build -t "${WORKLOAD}:latest" "./workloads/${WORKLOAD}"
        echo "[$count] Finished $WORKLOAD for $ENGINE"
        count=$((count + 1))
    done
done

# Final validation
echo "Validating image inventory..."
for ENGINE in "${ENGINES[@]}"; do
    echo "Engine: $ENGINE"
    for WORKLOAD in "${WORKLOADS[@]}"; do
        if $ENGINE images -q "${WORKLOAD}:latest" > /dev/null 2>&1; then
            echo "  - ${WORKLOAD}:latest   [OK]"
        else
            echo "  - ${WORKLOAD}:latest   [MISSING]"
        fi
    done
    echo
done