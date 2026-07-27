#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip

DURATION="${1:-$MCAST_DURATION}"
if (( DURATION > MAX_TEST_DURATION )); then
  echo "ERROR: duration exceeds MAX_TEST_DURATION=$MAX_TEST_DURATION" >&2
  exit 1
fi

SRC_IP="${WAN_IP%/*}"
ip netns exec "$WAN_NS" "$PROJECT_ROOT/scripts/mcast_sender.py" \
  --group "$MCAST_GROUP" \
  --port "$MCAST_PORT" \
  --interface "$SRC_IP" \
  --pps "$MCAST_PPS" \
  --payload "$MCAST_PAYLOAD" \
  --duration "$DURATION" \
  --ttl "$MCAST_TTL"
