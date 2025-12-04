#!/usr/bin/env bash
set -e

systemctl --user enable --now podman.socket
systemctl --user status podman.socket

podman info
