#!/usr/bin/env bash
set -e

ENGINES=("docker" "podman")
WORKLOADS=("web" "micro" "db")

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