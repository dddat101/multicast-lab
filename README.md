# Multicast & IGMP Packet Processing Lab Framework

A lightweight, zero-cost testbed framework for evaluating **IGMP Snooping/Proxying, Multicast Forwarding, and Packet Processing performance** on Network Gateways, Routers, and CPE Devices Under Test (DUT).

Using standard Linux utilities, network namespaces (`netns`), and `macvlan` sub-interfaces across two Linux host endpoints (PC 1 as WAN emulator, PC 2 as multi-STB LAN emulator), this framework provides a clean physical data path isolated from host management networks:

```text
+-----------------------+        +-------------------+        +-----------------------+
|   Ubuntu PC 1 (WAN)   |        |   DUT (Gateway)   |        |   Ubuntu PC 2 (LAN)   |
|                       |        |                   |        |                       |
|  [ns-wan / dnsmasq]   |        |  [WAN]     [LAN]  |        |  [ns-lan1..4 / STBs]  |
|  Multicast Sender     |<------>|                   |<------>|  Multicast Receivers  |
|  IGMP/Mcast Capture   |        | Device Under Test |        |  IGMP/Mcast Captures  |
+-----------------------+        +-------------------+        +-----------------------+
```

---

## 💡 Key Features & Architecture

- **Zero Data-Path Overhead**: Data path runs natively over physical NICs and Linux namespaces without Docker bridges, virtual switches, or nested NAT.
- **Upstream WAN Emulation**: Isolated WAN network namespace (`ns-wan`) running `dnsmasq` to assign WAN IP addresses to the DUT via DHCP.
- **Multi-Client LAN Emulation**: Scalable STB (Set-Top Box) client logic generated via MACVLAN interfaces inside distinct network namespaces (`ns-lan1`..`ns-lanN`), each receiving independent LAN DHCP leases.
- **Sequence-Tracked Multicast Streaming**: Python sender and receiver utilities featuring packet sequence numbering, configurable PPS limits, duration control, and detailed metrics (expected vs. unique, lost packets, loss ratio, duplicates).
- **Dual-Sided Capture & Analysis**: Simultaneous IGMP control plane and multicast data plane captures on both WAN and LAN sides with ready-to-use `tshark` filter commands (DSCP, DF flags, IGMP types).
- **Convenient Workflow**: Fully operable via Makefile targets (`make wan-up`, `make lan-up`, `make stop`, `make check`) or direct shell scripts.

---

## 1. Scope & Capability

This test suite automates environment setup, traffic generation, and telemetry collection:

| Component | Capabilities |
| :--- | :--- |
| **WAN Setup** | Configures `ns-wan` namespace, binds physical WAN NIC, launches `dnsmasq` DHCP server. |
| **LAN Setup** | Spawns `N` MACVLAN STB client namespaces (`ns-lan1` .. `ns-lanN`), requests DHCP from DUT. |
| **Traffic Generation** | Sends sequence-numbered UDP multicast streams with PPS and duration enforcement. |
| **Receiver Analysis** | Receives multicast streams across all STB namespaces; parses loss, duplicates, and out-of-order packets. |
| **Telemetry & Capture** | Captures PCAP traces at WAN/LAN interfaces; analyzes IGMP join/leave latencies and QoS headers. |
| **Host Diagnostics** | Quick interface state verification, offloading checks (`ethtool`), and hardware counter auditing. |

> **Note**: This framework does not mutate DUT configuration directly. Commands specific to your target device hardware (e.g., `ethtool`, `ip maddr`, `/proc/net/igmp`, acceleration engine CLI tools) should be executed directly on the DUT as dictated by your test plan.

---

## 2. Prerequisites & Installation

### Host Requirements (Ubuntu PC 1 & PC 2)

Install required base packages on both Linux endpoints:

```bash
sudo apt-get update
sudo apt-get install -y iproute2 dnsmasq tcpdump ethtool python3
```

Recommended additional utilities for traffic analysis and monitoring:

```bash
sudo apt-get install -y tshark sysstat
```

> ⚠️ **Important**: Dedicated test NICs must be physically separate from your primary SSH / management NICs. Do not assign active management interfaces to test namespaces.

---

## 3. Environment Configuration

1. Copy the example configuration template to create your local environment file:
   ```bash
   cp config/lab.env.example config/lab.env
   editor config/lab.env
   ```

2. Configure key environment parameters in `config/lab.env`:
   - `WAN_IF`: Physical NIC on Ubuntu PC 1 connected to DUT WAN.
   - `LAN_IF`: Physical NIC on Ubuntu PC 2 connected to DUT LAN.
   - `STB_COUNT`: Number of simulated STB client namespaces (default: `4`).
   - `RUNTIME_DIR`: Directory for logs and pid files (e.g., `/tmp/mcast-lab`).
   - Multicast parameters (`MCAST_GROUP`, `MCAST_PORT`, `MCAST_PPS`, `MCAST_PAYLOAD`, `MCAST_DURATION`).

3. Identify host network interface names:
   ```bash
   ip -br link
   ethtool -i <INTERFACE>
   ```

4. Disable NetworkManager management on dedicated test interfaces (if applicable):
   ```bash
   sudo nmcli device set <INTERFACE> managed no
   ```

---

## 4. Physical Cabling & Setup

### Physical Topology

```text
[Ubuntu PC 1: WAN_IF] <=================> [DUT: WAN Port]
[Ubuntu PC 2: LAN_IF] <=================> [DUT: LAN Port]
```

### Default Subnets

- **WAN Subnet** (Emulated by PC 1): `10.10.0.0/24` (DUT WAN receives dynamic IP from DHCP).
- **LAN Subnet** (Served by DUT): `192.168.1.0/24` (DUT LAN gateway `192.168.1.1`).

---

## 5. Environment Provisioning

You can use the provided Makefile shortcuts or execute scripts directly.

### Step 1: Provision WAN Environment (Ubuntu PC 1)

Using Makefile:
```bash
make wan-up
```
*Or manually:*
```bash
sudo ./scripts/setup_wan.sh
```

Verify WAN namespace status:
```bash
sudo ip netns exec ns-wan ip -br addr
cat /tmp/mcast-lab/dnsmasq.log
```

### Step 2: Provision LAN Environment (Ubuntu PC 2)

Using Makefile:
```bash
make lan-up
```
*Or manually:*
```bash
sudo ./scripts/setup_lan.sh
```

Verify STB client connectivity to DUT LAN Gateway (`192.168.1.1`):
```bash
for n in $(seq 1 4); do
  sudo ip netns exec ns-lan$n ping -c 2 192.168.1.1
done
```

---

## 6. Functional Multicast Test

1. **Start Multicast Receivers** on Ubuntu PC 2 (run receivers first to catch initial packets):
   ```bash
   sudo ./scripts/run_receivers.sh 60
   ```

2. **Start Multicast Sender** on Ubuntu PC 1:
   ```bash
   sudo ./scripts/run_sender.sh 60
   ```

3. **Inspect Test Logs**:
   Log files are written to the runtime directory defined in `config/lab.env` (e.g. `/tmp/mcast-lab/`):
   ```text
   /tmp/mcast-lab/receiver-1.log
   ...
   /tmp/mcast-lab/receiver-4.log
   ```

   Key metrics to verify:
   - `EXPECTED`: Total expected packets based on sequence numbers.
   - `UNIQUE`: Total distinct packets received.
   - `LOST`: Packet count missing from sequence.
   - `LOSS_RATIO`: Calculated packet loss percentage.
   - `DUPLICATES`: Count of duplicate packet arrivals.

---

## 7. Packet Capture & Traffic Analysis

### Simultaneous Captures

- **WAN Interface** (Ubuntu PC 1):
  ```bash
  sudo ./scripts/capture.sh wan 60 results/dut-wan.pcap
  ```

- **LAN Interface** (Ubuntu PC 2):
  ```bash
  sudo ./scripts/capture.sh lan 60 results/dut-lan.pcap
  ```

### IGMP & QoS Header Inspection (`tshark`)

Inspect IGMP Membership Queries/Reports, DSCP markings, and Don't Fragment (DF) flags:

```bash
tshark -r results/dut-wan.pcap \
  -Y igmp \
  -T fields \
  -e frame.time_epoch \
  -e eth.src \
  -e ip.src \
  -e ip.dst \
  -e ip.dsfield.dscp \
  -e ip.flags.df \
  -e igmp.type
```

---

## 8. DUT Verification & Telemetry Guidelines

Execute target commands on the DUT before, during, and after test runs to observe hardware acceleration, multicast snooping/proxy tables, and resource usage:

```bash
# Kernel Multicast Tables & Group Membership
cat /proc/net/igmp
cat /proc/net/ip_mr_cache
ip maddr

# Interface Statistics & Packet Drop Counters
ip -s link
ethtool -S <WAN_IF>
ethtool -S <LAN_IF>

# System CPU / Interrupt Utilization
top
cat /proc/softirqs
```

> 💡 **Tip**: If your DUT platform utilizes custom acceleration modules or IGMP Proxy daemons (e.g., vendor-specific `mcpctl`, `fcctl`, `swconfig`, or `shortcut-fe`), query their status tables alongside packet captures to verify active hardware flow offload.

---

## 9. Safety & Emergency Stop

Sender scripts enforce strict PPS and duration limits by default. **Never enable flood mode on unisolated hardware.**

To halt all running test scripts, senders, receivers, and capture tasks immediately:

Using Makefile:
```bash
make stop
```
*Or manually:*
```bash
sudo ./scripts/stop_tests.sh
```

> 🔒 **Safety Notice**: Run this test framework strictly in an isolated lab network. Do not emit multicast or DHCP server traffic to production enterprise or ISP networks.

---

## 10. Environment Teardown

### Teardown WAN (Ubuntu PC 1)

```bash
make wan-down
```
*Or manually:* `sudo ./scripts/cleanup_wan.sh`

### Teardown LAN (Ubuntu PC 2)

```bash
make lan-down
```
*Or manually:* `sudo ./scripts/cleanup_lan.sh`

Restore NetworkManager management for host NICs (if applicable):
```bash
sudo nmcli device set <INTERFACE> managed no # or 'yes' when done
```

---

## 11. Testbed Limitations & Recommendations

- **Physical Port Isolation**: `macvlan` enables multi-STB logical client emulation on a single physical interface. However, it cannot replace separate physical LAN cables when testing hardware switch-port isolation or per-port VLAN tagging.
- **NIC Hardware Selection**: USB Ethernet adapters may introduce CPU bottlenecks or artificial packet drops. Native PCIe network cards are strongly recommended for latency-critical (< 10 ms), low-loss (1e-9), or high-throughput benchmarks.
- **High-PPS Load Testing**: The included Python multicast sender/receiver scripts are tailored for functional, IGMP protocol compliance, and stability verification. For ultra-high PPS stress testing, consider using `trafgen`, `pktgen`, or dedicated hardware packet generators (e.g., Spirent, IXIA, Trex).
- **Timestamp Precision**: `tcpdump` software timestamps are adequate for functional pre-verification. For absolute IGMP join/leave latency certification, utilize NIC hardware timestamping (`SO_TIMESTAMPING`) or external hardware analyzers.
