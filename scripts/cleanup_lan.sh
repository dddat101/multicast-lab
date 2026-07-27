#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip

for n in $(seq 1 "$STB_COUNT"); do
  ns="ns-lan$n"
  if ip netns list | awk '{print $1}' | grep -qx "$ns"; then
    log "Deleting $ns"
    ip netns pids "$ns" | xargs -r kill 2>/dev/null || true
    ip netns del "$ns" || true
  fi
done

log "LAN cleanup complete"
