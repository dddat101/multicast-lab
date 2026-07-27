#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root
require_cmd ip
require_iface "$LAN_IF"

ip link set "$LAN_IF" up

for n in $(seq 1 "$STB_COUNT"); do
  ns="ns-lan$n"
  mv="mv-lan$n"
  host=$((STB_BASE_HOST + n - 1))
  addr="$LAN_PREFIX.$host/24"

  if ip netns list | awk '{print $1}' | grep -qx "$ns"; then
    log "$ns already exists; skipping"
    continue
  fi

  log "Creating $ns with $mv at $addr"
  ip netns add "$ns"
  ip link add "$mv" link "$LAN_IF" type macvlan mode bridge
  ip link set "$mv" netns "$ns"
  ip netns exec "$ns" ip link set lo up
  ip netns exec "$ns" ip link set "$mv" up
  ip netns exec "$ns" ip addr add "$addr" dev "$mv"
  ip netns exec "$ns" ip route replace default via "$DUT_LAN_GW"
done

log "LAN setup complete"
for n in $(seq 1 "$STB_COUNT"); do
  ip netns exec "ns-lan$n" ip -br addr
 done
