#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

ROLE="${1:-}"
case "$ROLE" in
  wan)
    require_iface "$WAN_IF"
    IF="$WAN_IF"
    ;;
  lan)
    require_iface "$LAN_IF"
    IF="$LAN_IF"
    ;;
  *)
    echo "Usage: $0 <wan|lan>" >&2
    exit 2
    ;;
esac

ip -br link show "$IF"
ip -br addr show "$IF"
ethtool "$IF" 2>/dev/null || true
ethtool -k "$IF" 2>/dev/null || true
ethtool -S "$IF" 2>/dev/null | head -n 80 || true
