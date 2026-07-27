#!/usr/bin/env python3
import argparse
import socket
import struct
import time


def main() -> None:
    p = argparse.ArgumentParser(description="UDP multicast receiver with sequence loss accounting")
    p.add_argument("--group", required=True)
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--interface", required=True, help="IPv4 address used for membership")
    p.add_argument("--duration", type=int, default=60)
    args = p.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("", args.port))
    membership = socket.inet_aton(args.group) + socket.inet_aton(args.interface)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
    sock.settimeout(1.0)

    start = time.monotonic()
    packets = 0
    bytes_rx = 0
    first_seq = None
    last_seq = None
    duplicates = 0
    seen = set()
    first_rx_ns = None

    try:
        while time.monotonic() - start < args.duration:
            try:
                data, _ = sock.recvfrom(65535)
            except socket.timeout:
                continue
            if first_rx_ns is None:
                first_rx_ns = time.monotonic_ns()
                print(f"FIRST_RX_NS={first_rx_ns}", flush=True)
            packets += 1
            bytes_rx += len(data)
            if len(data) >= 16:
                seq, _ = struct.unpack("!QQ", data[:16])
                if seq in seen:
                    duplicates += 1
                else:
                    seen.add(seq)
                first_seq = seq if first_seq is None else min(first_seq, seq)
                last_seq = seq if last_seq is None else max(last_seq, seq)
    finally:
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_DROP_MEMBERSHIP, membership)

    expected = 0 if first_seq is None else (last_seq - first_seq + 1)
    unique = len(seen)
    lost = max(0, expected - unique)
    loss_ratio = 0.0 if expected == 0 else lost / expected
    print(f"PACKETS={packets}")
    print(f"UNIQUE={unique}")
    print(f"DUPLICATES={duplicates}")
    print(f"EXPECTED={expected}")
    print(f"LOST={lost}")
    print(f"LOSS_RATIO={loss_ratio:.12g}")
    print(f"BYTES={bytes_rx}")


if __name__ == "__main__":
    main()
