#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_root

pkill -f mcast_sender.py 2>/dev/null || true
pkill -f mcast_receiver.py 2>/dev/null || true
pkill -f 'tcpdump.*239.0.0.0/8' 2>/dev/null || true
log "Stopped sender, receiver and capture processes"
