# OpenVPN for Docker (with DCO)

Fork of [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn) updated for OpenVPN 2.6+ with **Data Channel Offload (DCO)** support.

## Changes from upstream

- **Ubuntu 24.04** base instead of Alpine (OpenVPN 2.6.19 with `[DCO]` compiled in)
- **Modern AEAD ciphers** by default: AES-256-GCM, AES-128-GCM, CHACHA20-POLY1305
- **tls-crypt** in client template instead of tls-auth
- **allow-compression no** replaces deprecated comp-lzo
- Removed obsolete aarch64 Dockerfile (Ubuntu is multi-arch)

## DCO requirements

DCO offloads encryption/decryption to the Linux kernel, eliminating userspace context switches. Requirements:

- Host kernel 6.8+ with `ovpn-dco-v2` module, or kernel 6.16+ with built-in `ovpn`
- `topology subnet` in server config (required for DCO)
- AEAD cipher (AES-GCM or CHACHA20-POLY1305)
- Client OpenVPN 2.6+ (older clients still work without DCO)

## Quick start

```bash
# Create data volume
docker volume create ovpn-data

# Generate config
docker compose run --rm openvpn ovpn_genconfig -u udp://VPN.SERVERNAME.COM
docker compose run --rm openvpn ovpn_initpki

# Start
docker compose up -d
```

## docker-compose.yml

```yaml
services:
  openvpn:
    build: .
    container_name: openvpn
    cap_add:
      - NET_ADMIN
    network_mode: host
    environment:
      - OVPN_NATDEVICE=eth0
    volumes:
      - ovpn-data:/etc/openvpn
      - /lib/modules:/lib/modules:ro
    devices:
      - /dev/net/tun:/dev/net/tun
    restart: always

volumes:
  ovpn-data:
    external: true
```

Key additions vs upstream:
- `network_mode: host` for direct network access and proper NAT
- `/lib/modules` mount for DCO kernel module access
- `OVPN_NATDEVICE` set to your LAN interface

## Server config for DCO

Add to your `openvpn.conf`:

```
topology subnet
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM
tls-crypt /etc/openvpn/pki/ta.key
allow-compression no
explicit-exit-notify
```

## Load DCO kernel module

```bash
# Load now
sudo modprobe ovpn-dco-v2

# Persist across reboots
echo "ovpn-dco-v2" | sudo tee /etc/modules-load.d/ovpn-dco.conf
```

## Verify DCO is active

```bash
# Check interface type (should show ovpn-dco, not tun)
ip -d link show tun0 | grep ovpn-dco

# Check server logs
docker logs openvpn 2>&1 | grep DCO
# DCO device tun0 opened

# Check status file
docker exec openvpn cat /tmp/openvpn-status.log | grep dco_enabled
# GLOBAL_STATS,dco_enabled,1
```

## Generate client config

```bash
docker exec openvpn easyrsa build-client-full CLIENT nopass
docker exec openvpn ovpn_getclient CLIENT > CLIENT.ovpn
```

Client configs automatically use `tls-crypt` and `allow-compression no`.

## Firewall

If your host has a DROP policy on the FORWARD chain, allow VPN traffic:

```bash
iptables -I FORWARD -i tun0 -o eth0 -s 192.168.255.0/24 -j ACCEPT
iptables -I FORWARD -i eth0 -o tun0 -d 192.168.255.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Upstream

Based on [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn). See upstream for full documentation on EasyRSA, OTP, and advanced configuration.
