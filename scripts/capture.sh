#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd tcpdump
ensure_runtime_dir

SIDE="${1:-}"
DURATION="${2:-60}"
OUT="${3:-$RUNTIME_DIR/capture-${SIDE:-unknown}-$(date +%Y%m%d_%H%M%S).pcap}"

case "$SIDE" in
  wan)
    require_cmd ip
    timeout "$DURATION" ip netns exec "$WAN_NS" tcpdump -ni "$WAN_IF" -e -s 0 -B 8192 \
      -w "$OUT" 'igmp or (udp and dst net 239.0.0.0/8)'
    ;;
  lan)
    require_iface "$LAN_IF"
    timeout "$DURATION" tcpdump -ni "$LAN_IF" -e -s 0 -B 8192 \
      -w "$OUT" 'igmp or (udp and dst net 239.0.0.0/8)'
    ;;
  *)
    echo "Usage: sudo $0 <wan|lan> [duration_s] [output.pcap]" >&2
    exit 2
    ;;
esac

echo "$OUT"
