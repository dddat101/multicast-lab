#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip
ensure_runtime_dir

DURATION="${1:-$MCAST_DURATION}"
if (( DURATION > MAX_TEST_DURATION )); then
  echo "ERROR: duration exceeds MAX_TEST_DURATION=$MAX_TEST_DURATION" >&2
  exit 1
fi

for n in $(seq 1 "$STB_COUNT"); do
  host=$((STB_BASE_HOST + n - 1))
  ipaddr="$LAN_PREFIX.$host"
  log "Starting receiver in ns-lan$n ($ipaddr)"
  ip netns exec "ns-lan$n" "$PROJECT_ROOT/scripts/mcast_receiver.py" \
    --group "$MCAST_GROUP" \
    --port "$MCAST_PORT" \
    --interface "$ipaddr" \
    --duration "$DURATION" \
    >"$RUNTIME_DIR/receiver-$n.log" 2>&1 &
  echo $! > "$RUNTIME_DIR/receiver-$n.pid"
done

wait
log "Receiver results"
for n in $(seq 1 "$STB_COUNT"); do
  echo "===== ns-lan$n ====="
  cat "$RUNTIME_DIR/receiver-$n.log"
done
