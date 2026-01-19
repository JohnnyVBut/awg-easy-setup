# Installation Guide

[Русская версия](../ru/INSTALLATION.md) | **English**

## Quick Start

### Recommended: One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Or with wget:**

```bash
wget -qO /tmp/awg-setup.sh https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh && sudo bash /tmp/awg-setup.sh
```

### Alternative: Manual verification

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh

# Verify syntax
bash -n /tmp/awg-setup.sh

# Review content (optional)
less /tmp/awg-setup.sh

# Run installation
sudo bash /tmp/awg-setup.sh
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

## Installation Methods Explained

### Method 1: One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Why this method:**
- ✅ Single copy-paste command
- ✅ Reliable execution (file-based, avoids shell parsing issues)
- ✅ Script downloaded fully before execution
- ✅ Works consistently across all systems

**How it works:**
1. Downloads script to `/tmp/awg-setup.sh`
2. Only runs if download succeeds (`&&` operator)
3. Executes from filesystem (not piped)

### Method 2: Clone Repository

```bash
git clone https://github.com/JohnnyVBut/awg-easy-setup.git
cd awg-easy-setup
sudo bash setup.sh
```

**When to use:**
- Want full repository access
- Need to modify scripts
- Building custom deployment

### Method 3: Specific Release

```bash
curl -fsSL https://github.com/JohnnyVBut/awg-easy-setup/releases/download/v1.0.0/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**When to use:**
- Production deployments
- Need reproducible installs
- Pin to tested version

## Next Steps

- [Configure AmneziaVPN clients](CLIENTS.md)
- [Review security model](SECURITY.md)
- [Troubleshooting guide](TROUBLESHOOTING.md)
