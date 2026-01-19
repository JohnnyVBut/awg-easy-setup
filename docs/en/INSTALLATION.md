# Installation Guide

[Русская версия](../ru/INSTALLATION.md) | **English**

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/awg-easy-setup/main/setup.sh | sudo bash
```

## Requirements

- Ubuntu 20.04+ or Debian 11+
- 1GB RAM minimum
- Root access
- Fresh installation recommended

## Installation Steps

### 1. Update System [1-2/11]
Script updates packages and installs Docker from official repository.

### 2. Create User [3/11]
10-second prompt for username (defaults to `admino`).

### 3. Setup SSH [4-6/11]
- Generates Ed25519 keys
- Imports root's authorized_keys
- Hardens SSH config (port 9722, keys-only)

### 4. Configure Firewall [7/11]
Opens SSH (9722/tcp) and AmneziaWG (54321/udp) ports.

### 5. Deploy Container [8/11]
Runs awg-easy container with temporary UI access.

**CRITICAL**: Create VPN client before pressing ENTER!

### 6. Lock UI [9/11]
Restricts web UI to VPN-only access (10.8.0.0/24).

### 7. Summary & Reboot [10-11/11]
Displays credentials and reboots server.

## Post-Installation

```bash
# Connect via SSH
ssh -p 9722 admino@YOUR_SERVER_IP

# Check status
docker ps | grep awg-easy
sudo ufw status
sudo iptables -S DOCKER-USER
```

## Verification

```bash
# Test UI lockdown (should timeout)
curl --max-time 5 http://YOUR_SERVER_IP:8888

# Connect to VPN, then test (should work)
curl http://10.8.0.1:8888
```

## Next Steps

- [Configure AmneziaVPN clients](CLIENTS.md)
- [Review security model](SECURITY.md)
- [Troubleshooting guide](TROUBLESHOOTING.md)
