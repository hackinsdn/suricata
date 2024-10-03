# HackInSDN - Suricata Docker image

Overview
========

This is the repository for the `hackinsdn/suricata` Docker image which is a docker image including Suricata IDS with emerging threat rules plus some custom rules developed on the HackInSDN Project (see more at https://hackinsdn.github.io).

One of the main use cases of this image is its integration into Mininet-sec (https://mininet-sec.github.io)

Getting Started
===============

The simpleset way of running this is leveraging the pre-build imagem from Docker Hub:
```
docker pull hackinsdn/suricata:latest
docker run -d --name suricata -e SURICATA_IFACE=eth0 -e SURICATA_HOME_NET=192.168.0.0/16,10.0.0.0/8 hackinsdn/suricata:latest
```

Available environment variables are:
- `SURICATA_IFACE`: Name of the network interface in which Suricata will listen to packets (see Network Interfaes section below)
- `SURICATA_HOME_NET`: Networks to be considered your networks to be monitored
- `KYTOS_URL`: used to make Suricata work in IPS Mode with remote blocking via Kytos by default (can be customized by modifying `scripts/{block.sh,unblock.sh}`)
- `BLOCKING_DURATION`: time (in seconds) to block a host

If you prefer to build your own image:
```
git clone https://github.com/hackinsdn/suricata
cd suricata-docker
docker build -t hackinsdn/suricata .
```

Network Interfaces
==================

One of the most important aspects of running this image is to make packets available to be processed by the container. Currently only `af-packet` listen mode is supported, so you have to make an interface available into the container. Many strategies can be applied:
- Creating VXLAN tunnels from your original traffic source (e.g, Network TAPs) -- this is the strategy adopted by Mininet-Sec
- Creating a MACVLAN network on Docker host and attach it to your `hackinsdn/suricata` container: https://docs.docker.com/engine/network/tutorials/macvlan/
- Leveraging the Linux Network Namespace capabilities to move a physical interface from your Docker host into `hackinsdn/suricata` container (root privileges needed, assuming `suricata` as the container name):
```
CONTAINER_NAME=suricata
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER_NAME)
mkdir -p /var/run/netns
ln -sf /proc/$PID/ns/net /var/run/netns/$CONTAINER_NAME

# now you have two options: (1) create a veth interface or (2) attach an existing interface
# option 1: create a veth interface to attach:
ip link add veth0 type veth peer name veth1
ip link set veth1 netns $CONTAINER_NAME
ip netns exec $CONTAINER_NAME ip link set up veth1
ip link set up veth0

# option 2: attach an existing interface (let's say enp0s0)
ip link set enp0s0 netns $CONTAINER_NAME
ip netns exec $CONTAINER_NAME ip link set up enp0s0
```

If you are interested only on experimenting or testing, the easiest way of using this is through the Mininet-sec! :-)

Rules
=====

The following rules are enabled by default when using `hackinsdn/suricata` without customizations:
- Proofpoint's Emerging Threats community rules
- OPNsense's Suricata IDS/IPS Detection Rules Against Nmap Scans by Aleksi Bovellan (https://github.com/aleksibovellan/opnsense-suricata-nmaps)
- HackInSDN's custom rules developed for specific attacks like scanning, brute-force, DNS tunnels, etc

IPS Mode - Dropping/blocking attackers
======================================

If you are interested in using Suricata in IPS mode to enable dropping the packets or blocking the attacker's IP, please consider the following options:
1. Suricata running "inline" with the traffic
2. Suricata running with "traffic mirror"

The original idea of using `hackinsdn/suricata` was related to the "traffic mirror" approach, in which the traffic is somehow exported to Suricata (typically through a traffic mirror strategy), Suricata generate _alerts_ and those alerts are consumed by some tool (e.g., `hackinsdn-guardian.py` -- see below) to trigger *blocking requests* on a external system (Firewall, Router with Flowspec, SDN Orchestrator, etc). *Only rules configured to block are actually used to trigger blocking requests!* Please check the file `conf/suricata/drop.conf` to include rules by ID, Group, Metadata, etc. The `drop.conf` file is processed by `suricata-update` to change a rule to `drop` action. Additionally, we configure Suricata to run with the paramenter `--simulate-ips`, so that the action is logged to `eve.json` (json output) and can be consumed by `hackinsdn-guardian.py` to trigger blocking requests.

In the HackInSDN project, we have developed tools that enable the integration of Suricata with Kytos-ng SDN Orchestrator. Thus, upon identifying an _alert_ via Suricata's eve log we extract the VLAN ID and source IP address, then we send a containment request to Kytos-ng to block the attacker's IP. After a configurable amount of time, the IP is unblocked.

Please refer to the scripts `scripts/hackinsdn-guardian.py` to better understand the logging parsing and alerts identification phase, and the scripts `scripts/block.sh` and `scripts/unblock.sh` for Kytos-ng specific calls to block and unblock the IP/VLAN.
