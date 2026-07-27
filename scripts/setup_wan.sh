#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip
require_cmd dnsmasq
require_iface "$WAN_IF"
ensure_runtime_dir

if ip netns list | awk '{print $1}' | grep -qx "$WAN_NS"; then
  log "Namespace $WAN_NS already exists; cleaning stale state first."
  "$PROJECT_ROOT/scripts/cleanup_wan.sh" || true
fi

log "Creating WAN namespace $WAN_NS on $WAN_IF"
ip link set "$WAN_IF" down
ip netns add "$WAN_NS"
ip link set "$WAN_IF" netns "$WAN_NS"
ip netns exec "$WAN_NS" ip link set lo up
ip netns exec "$WAN_NS" ip link set "$WAN_IF" up
ip netns exec "$WAN_NS" ip addr flush dev "$WAN_IF"
ip netns exec "$WAN_NS" ip addr add "$WAN_IP" dev "$WAN_IF"

cat > "$RUNTIME_DIR/dnsmasq-wan.conf" <<CFG
interface=$WAN_IF
bind-interfaces
dhcp-range=$WAN_DHCP_START,$WAN_DHCP_END,255.255.255.0,12h
dhcp-option=3,$WAN_DHCP_ROUTER
dhcp-option=6,$WAN_DHCP_ROUTER
log-dhcp
pid-file=$RUNTIME_DIR/dnsmasq.pid
leasefile-ro
CFG

log "Starting dnsmasq in $WAN_NS"
ip netns exec "$WAN_NS" dnsmasq \
  --conf-file="$RUNTIME_DIR/dnsmasq-wan.conf" \
  --log-facility="$RUNTIME_DIR/dnsmasq.log"

log "WAN setup complete"
ip netns exec "$WAN_NS" ip -br link
ip netns exec "$WAN_NS" ip -br addr
