#!/usr/bin/env python3
import argparse
import socket
import struct
import time


def main() -> None:
    p = argparse.ArgumentParser(description="Rate-limited UDP multicast sender")
    p.add_argument("--group", required=True)
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--interface", required=True, help="IPv4 source address")
    p.add_argument("--pps", type=int, default=1000)
    p.add_argument("--payload", type=int, default=1200)
    p.add_argument("--duration", type=int, default=60)
    p.add_argument("--ttl", type=int, default=16)
    args = p.parse_args()

    if args.pps <= 0 or args.duration <= 0:
        raise SystemExit("pps and duration must be positive")
    if args.payload < 16:
        raise SystemExit("payload must be at least 16 bytes")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(args.interface))
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, args.ttl)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 0)

    interval_ns = 1_000_000_000 // args.pps
    start = time.monotonic_ns()
    end = start + args.duration * 1_000_000_000
    next_send = start
    seq = 0
    padding = bytes(args.payload - 16)

    while time.monotonic_ns() < end:
        now = time.monotonic_ns()
        payload = struct.pack("!QQ", seq, now) + padding
        sock.sendto(payload, (args.group, args.port))
        seq += 1
        next_send += interval_ns
        while True:
            remaining = next_send - time.monotonic_ns()
            if remaining <= 0:
                break
            if remaining > 200_000:
                time.sleep((remaining - 100_000) / 1_000_000_000)

    print(f"SENT={seq}")


if __name__ == "__main__":
    main()
