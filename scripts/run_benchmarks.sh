#!/usr/bin/env bash
set -euo pipefail

ENGINE=${1:?engine required}
WORKLOAD=${2:?workload required}
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
DATA_DIR="data"
TMP_PORT_FILE="/tmp/bench_ports_${USER}.txt"

mkdir -p "$DATA_DIR"
mkdir -p "${DATA_DIR}/${ENGINE}-${WORKLOAD}"
mkdir -p "${DATA_DIR}/${ENGINE}-web"
mkdir -p "${DATA_DIR}/${ENGINE}-db"
mkdir -p data/${ENGINE}-micro
mkdir -p data/${ENGINE}-micro-balanced
mkdir -p data/${ENGINE}-micro-heavy_cpu
mkdir -p data/${ENGINE}-micro-heavy_io
mkdir -p data/${ENGINE}-${WORKLOAD}-top
mkdir -p data/${ENGINE}-${WORKLOAD}-ps
mkdir -p data/${ENGINE}-${WORKLOAD}-df
mkdir -p data/${ENGINE}-${WORKLOAD}-net
mkdir -p "data/energy-${ENGINE}-${WORKLOAD}"


case "$ENGINE" in
    docker) R="docker" ;;
    podman) R="podman" ;;
    *) echo "Invalid engine: $ENGINE" >&2; exit 1 ;;
esac

ALLOCATED_PORTS=()
CONTAINERS_STARTED=()
CONTAINER_LABEL="bench_${ENGINE}_${WORKLOAD}_${timestamp}"

# Ensure tmp port file exists
touch "$TMP_PORT_FILE"

# Cleanup routine runs on EXIT (normal or error)
cleanup() {
  rc=$?
  echo "Running cleanup (exit code: $rc) ..." >&2

  # Remove containers by label (stopped or running)
  if [ "$R" = "docker" ]; then
    docker ps -a --filter "label=bench_run=${CONTAINER_LABEL}" -q | xargs -r docker rm -f >/dev/null 2>&1 || true
  else
    podman ps -a --filter "label=bench_run=${CONTAINER_LABEL}" -q | xargs -r podman rm -f >/dev/null 2>&1 || true
  fi

  # Kill any processes owning allocated ports
  for P in "${ALLOCATED_PORTS[@]}"; do
    if pid=$(lsof -t -i :"$P" 2>/dev/null || true); then
      if [ -n "$pid" ]; then
        echo "Killing PID(s) $pid listening on port $P" >&2
        kill -9 $pid 2>/dev/null || true
      fi
    fi
    # Remove port entry from global tmp file
    if [ -f "$TMP_PORT_FILE" ]; then
      grep -v -F "$P" "$TMP_PORT_FILE" > "${TMP_PORT_FILE}.tmp" || true
      mv -f "${TMP_PORT_FILE}.tmp" "$TMP_PORT_FILE" || true
    fi
  done

  echo "Cleanup completed." >&2
  return $rc
}

trap cleanup EXIT

# Helpers
free_port() {
  local PORT=$1
  if sudo lsof -i :"$PORT" -t >/dev/null 2>&1; then
    echo "Port $PORT in use — killing owners."
    sudo lsof -i :"$PORT" -t | xargs -r sudo kill -9 || true
  fi
}

get_free_port() {
  while :; do
    PORT=$((RANDOM % 54511 + 1024))
    if ! sudo lsof -i :$PORT -t >/dev/null 2>&1; then
      echo "$PORT"
      return
    fi
  done
}

wait_for_tcp() {
  local HOST=$1
  local PORT=$2
  local retries=30
  local i=0
  while ! nc -z "$HOST" "$PORT" >/dev/null 2>&1; do
    i=$((i+1))
    if [ $i -ge $retries ]; then
      echo "Timeout waiting for $HOST:$PORT" >&2
      return 1
    fi
    sleep 1
  done
  return 0
}

# MAIN: start workload, benchmark, record port, label container
case "$WORKLOAD" in
    web)
        HOST_PORT=$(get_free_port)
        free_port "$HOST_PORT"
        ALLOCATED_PORTS+=("$HOST_PORT")
        echo "$HOST_PORT" >> "$TMP_PORT_FILE"

        CONTAINER_PORT=80
        echo "Starting web container (host:$HOST_PORT -> container:$CONTAINER_PORT)..."
        # label container so cleanup can find it reliably
        $R run --rm -d --label bench_run=${CONTAINER_LABEL} --cpus=1 --memory=512m -p ${HOST_PORT}:${CONTAINER_PORT} web:latest

        echo "Waiting for web service..."
        wait_for_tcp 127.0.0.1 "$HOST_PORT" || { echo "Web service did not start"; exit 1; }
        echo "Running HTTP benchmark (ab) against localhost:${HOST_PORT}..."
        ab -n 1000 -c 100 http://localhost:${HOST_PORT}/ > "${DATA_DIR}/${ENGINE}-web/${timestamp}.log" 2>&1 || true
    ;;

    db)
        HOST_PORT=$(get_free_port)
        free_port "$HOST_PORT"
        ALLOCATED_PORTS+=("$HOST_PORT")
        echo "$HOST_PORT" >> "$TMP_PORT_FILE"

        CONTAINER_PORT=5432
        echo "Starting db container (host:${HOST_PORT} -> container:${CONTAINER_PORT})..."
        $R run --rm -d --name "${CONTAINER_LABEL}" \
            --label bench_run=${CONTAINER_LABEL} \
            --cpus=1 --memory=1g \
            -e POSTGRES_USER=postgres \
            -e POSTGRES_PASSWORD=test123 \
            -e POSTGRES_DB=testdb \
            -p ${HOST_PORT}:${CONTAINER_PORT} db:latest

        # Wait for Postgres readiness using pg_isready
        echo "Waiting for Postgres readiness on host port ${HOST_PORT}..."
        retries=30
        until PGPASSWORD=test123 psql -h 127.0.0.1 -p "$HOST_PORT" -U postgres -d testdb -c '\q' >/dev/null 2>&1 || [ $retries -le 0 ]; do
            sleep 2
            retries=$((retries-1))
        done

        if [ $retries -le 0 ]; then
            echo "Postgres did not become ready on ${HOST_PORT}" >&2
            $R logs "${CONTAINER_LABEL}" || true
            exit 1
        fi

        echo "Preparing Sysbench schema..."
        sysbench --db-driver=pgsql \
        --pgsql-host=127.0.0.1 --pgsql-port=${HOST_PORT} \
        --pgsql-user=postgres --pgsql-password=test123 \
        --pgsql-db=testdb \
        oltp_read_write --tables=5 --table-size=50000 prepare > "${DATA_DIR}/${ENGINE}-db/${timestamp}-prepare.log" 2>&1 || true

        echo "Running sysbench against Postgres on port ${HOST_PORT}..."
        sysbench --db-driver=pgsql \
        --pgsql-host=127.0.0.1 --pgsql-port=${HOST_PORT} \
        --pgsql-user=postgres --pgsql-password=test123 \
        --pgsql-db=testdb \
        oltp_read_write --tables=5 --table-size=50000 run > "${DATA_DIR}/${ENGINE}-db/${timestamp}.log" 2>&1 || true

        echo "Cleaning up Sysbench test tables..."
        sysbench --db-driver=pgsql \
        --pgsql-host=127.0.0.1 --pgsql-port=${HOST_PORT} \
        --pgsql-user=postgres --pgsql-password=test123 \
        --pgsql-db=testdb \
        oltp_read_write --tables=5 --table-size=50000 cleanup > "${DATA_DIR}/${ENGINE}-db/${timestamp}-cleanup.log" 2>&1 || true

    ;;


    micro)
        HOST_PORT=$(get_free_port)
        free_port "$HOST_PORT"
        ALLOCATED_PORTS+=("$HOST_PORT")
        echo "$HOST_PORT" >> "$TMP_PORT_FILE"

        CONTAINER_PORT=5000
        echo "Starting micro container (host:${HOST_PORT} -> container:${CONTAINER_PORT})..."
        $R run --rm -d --label bench_run=${CONTAINER_LABEL} --cpus=2 --memory=512m -p ${HOST_PORT}:${CONTAINER_PORT} micro:latest

        echo "Waiting for microservice..."
        wait_for_tcp 127.0.0.1 "$HOST_PORT" || { echo "Microservice did not start"; exit 1; }

        echo "Running wrk against localhost:${HOST_PORT}..."
        wrk -t4 -c100 -d30s http://localhost:${HOST_PORT} > "${DATA_DIR}/${ENGINE}-micro/${timestamp}.log" 2>&1 || true

        MICRO_TARGET="http://localhost:${HOST_PORT}" \
        python3 workloads/micro/benchmark_matrix.py balanced 30 50 > data/${ENGINE}-micro-balanced/${timestamp}.log 2>&1

        MICRO_TARGET="http://localhost:${HOST_PORT}" \
        python3 workloads/micro/benchmark_matrix.py heavy_cpu 30 50 > data/${ENGINE}-micro-heavy_cpu/${timestamp}.log 2>&1

        MICRO_TARGET="http://localhost:${HOST_PORT}" \
        python3 workloads/micro/benchmark_matrix.py heavy_io 30 50 > data/${ENGINE}-micro-heavy_io/${timestamp}.log 2>&1

    ;;

    *)
        echo "Invalid workload: $WORKLOAD" >&2
        exit 1
    ;;
esac

echo "Benchmark completed for ${WORKLOAD} on ${ENGINE}."
# explicit cleanup will be executed via trap
exit 0