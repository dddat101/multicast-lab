#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip

if ip netns list | awk '{print $1}' | grep -qx "$WAN_NS"; then
  log "Stopping services in $WAN_NS"
  ip netns pids "$WAN_NS" | xargs -r kill 2>/dev/null || true
  sleep 1

  if ip netns exec "$WAN_NS" ip link show "$WAN_IF" >/dev/null 2>&1; then
    ip netns exec "$WAN_NS" ip link set "$WAN_IF" down || true
    ip netns exec "$WAN_NS" ip link set "$WAN_IF" netns 1 || true
  fi
  ip netns del "$WAN_NS" || true
fi

if ip link show "$WAN_IF" >/dev/null 2>&1; then
  ip link set "$WAN_IF" up || true
fi

log "WAN cleanup complete"
