#!/usr/bin/env bash
set -e

ENGINE=$1
WORKLOAD=$2
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p data/${ENGINE}-${WORKLOAD}-top
mkdir -p data/${ENGINE}-${WORKLOAD}-ps
mkdir -p data/${ENGINE}-${WORKLOAD}-df
mkdir -p data/${ENGINE}-${WORKLOAD}-net

# CPU / Memory snapshot
top -b -n 1 > data/${ENGINE}-${WORKLOAD}-top/$timestamp.log
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu > data/${ENGINE}-${WORKLOAD}-ps/$timestamp.log

# Disk usage
df -h > data/${ENGINE}-${WORKLOAD}-df/$timestamp.log

# Network stats
ss -tulwn > data/${ENGINE}-${WORKLOAD}-net/$timestamp.log
