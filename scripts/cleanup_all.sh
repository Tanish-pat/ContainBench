#!/usr/bin/env bash
set -euo pipefail

TMP_PORT_FILE="/tmp/bench_ports_${USER}.txt"

if [ ! -f "$TMP_PORT_FILE" ]; then
  echo "No tmp port file ($TMP_PORT_FILE) — nothing to clean."
  exit 0
fi

echo "Cleaning ports listed in $TMP_PORT_FILE ..."

while IFS= read -r PORT || [ -n "$PORT" ]; do
  [ -z "$PORT" ] && continue
  echo "Cleaning port $PORT ..."
  # kill processes listening on that port
  if pid=$(lsof -t -i :"$PORT" 2>/dev/null || true); then
    if [ -n "$pid" ]; then
      echo "Killing PID(s) $pid listening on $PORT"
      kill -9 $pid 2>/dev/null || true
    fi
  fi

  # Remove any Docker/Podman container that exposes this port (best-effort)
  docker ps -a --format '{{.ID}} {{.Ports}}' 2>/dev/null | grep -F ":$PORT" | awk '{print $1}' | xargs -r docker rm -f >/dev/null 2>&1 || true
  podman ps -a --format '{{.ID}} {{.Ports}}' 2>/dev/null | grep -F ":$PORT" | awk '{print $1}' | xargs -r podman rm -f >/dev/null 2>&1 || true

done < "$TMP_PORT_FILE"

# clear the file
> "$TMP_PORT_FILE"
echo "Cleanup_all completed."
