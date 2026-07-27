#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${LAB_ENV_FILE:-$PROJECT_ROOT/config/lab.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  echo "Copy config/lab.env.example to config/lab.env and edit interface names." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: Run as root (sudo)." >&2
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  }
}

require_iface() {
  local ifname="$1"
  ip link show "$ifname" >/dev/null 2>&1 || {
    echo "ERROR: Interface not found: $ifname" >&2
    exit 1
  }
}

ensure_runtime_dir() {
  mkdir -p "$RUNTIME_DIR"
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}
