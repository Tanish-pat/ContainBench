#!/usr/bin/env bash
set -e

export PATH=$HOME/bin:$PATH
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

nohup dockerd-rootless.sh --experimental --storage-driver overlay2 > /tmp/dockerd-rootless.log 2>&1 &
sleep 5

docker info
