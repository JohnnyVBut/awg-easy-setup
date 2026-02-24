# AWG-Easy Setup Script

🔒 Automated deployment of a hardened AmneziaWG VPN server on Ubuntu/Debian

[Русская версия](README.ru.md) | **English**

## Quick Installation

**⚠️ Run only on a fresh server!**

### Recommended: One-line install (download → run)

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Or with wget:**

```bash
wget -qO /tmp/awg-setup.sh https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh && sudo bash /tmp/awg-setup.sh
```

### Alternative: Manual verification

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh -o /tmp/awg-setup.sh

# Verify syntax
bash -n /tmp/awg-setup.sh

# Review content (optional)
less /tmp/awg-setup.sh

# Run installation
sudo bash /tmp/awg-setup.sh
```

## What Does This Script Do?

✅ Updates system and installs Docker (official repository)  
✅ Creates a hardened sudo user  
✅ Configures SSH (keys-only, non-standard port, root disabled)  
✅ Deploys AmneziaWG VPN container  
✅ **Automatically creates first VPN client via API**  
✅ **Displays QR code and one-time download link in terminal**  
✅ **Automatically locks web UI after initial setup**  

## Security Features

- **SSH**: Public keys only, port 9722, root login disabled
- **VPN UI**: Accessible **only from VPN** (10.8.0.0/24) after bootstrap
- **Random passwords** for all accounts (24 chars base64, ~144 bits entropy)
- **UFW + iptables DOCKER-USER** double protection
- **Systemd persistence** for firewall rules across reboots

## System Requirements

- Ubuntu 20.04+ or Debian 11+ 
- Minimum 1GB RAM
- Root access
- Fresh installation (recommended)
- Internet connection for package installation

## Installation Process

### Step 1: Username Prompt (10 seconds)
```
[3/12] Creating a sudo user (you have 10 seconds to type a name)...
Enter new username (10s timeout): _
```
Type a username or wait for timeout → defaults to `admino`

### Step 2: Automated VPN Client Creation (NEW!)
```
[9/12] Creating first VPN client via API...
→ Authenticating...
✓ Authenticated successfully
→ Creating VPN client...
✓ Client created successfully
✓ Client ID: 4acaf6ff-8d16-4edf-96ef-560f5885be53
→ Generating one-time download link...
✓ One-time link generated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ FIRST VPN CLIENT CREATED!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Download config (ONE-TIME LINK - expires after download):
  http://YOUR_IP:8888/cnf/abc123def456...

QR Code (scan with WireGuard mobile app):
█████████████████████████████████
███ ▄▄▄▄▄ █▀█ █▄▄▀▄█ ▄▄▄▄▄ ███
███ █   █ █▀▀▀ ▀ ▄ █ █   █ ███
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Actions:**
1. **Scan the QR code** with AmneziaWG mobile app, OR
2. **Click the one-time link** to download config file
3. **⚠️ Save the link immediately** - it expires after first download!

### Step 3: Web UI Access (Optional)
```
>>> TEMPORARY Web UI access is OPEN to the Internet.
    You can also access Web UI at:
    URL:  http://YOUR_IP:8888
    User: admin
    Pass: [SHOWN IN OUTPUT]

Press ENTER to lock the Web UI to VPN-only access...
```

**Optional:** You can create additional clients via Web UI before locking it.

### Step 4: Save Credentials
```
==================== SUMMARY ====================
 User:                    admino
 User password:           [RANDOM PASSWORD]
 Root password:           [RANDOM PASSWORD]
 SSH:                     port 9722
 Web UI password:         [RANDOM PASSWORD]
=================================================
Press any key to reboot the host...
```

**⚠️ CRITICAL:** Copy the entire output before reboot!

### Step 4: Connect After Reboot

```bash
# SSH connection with new port:
ssh -p 9722 admino@YOUR_SERVER_IP

# If key wasn't imported, use the "User password" from output
```

## Post-Installation

### Access Web UI from VPN
```bash
# Connect to VPN first, then open:
http://10.8.0.1:8888
```

### Verify Installation
```bash
# Container status
docker ps | grep awg-easy

# VPN logs
docker logs awg-easy

# Firewall rules
sudo ufw status verbose
sudo iptables -S DOCKER-USER

# Systemd unit
systemctl status lock-awg-ui.service
```

## Documentation

- 📖 [Installation Guide](docs/en/INSTALLATION.md)
- 🔒 [Security Model](docs/en/SECURITY.md)
- 🔧 [Troubleshooting](docs/en/TROUBLESHOOTING.md)
- 📱 [Client Configuration](docs/en/CLIENTS.md)

## Architecture

```
Internet
   │
   ├─[SSH:9722/tcp]──────────► sshd (pubkey only, no root)
   │
   ├─[AWG:54321/udp]─────────► Docker:awg-easy (AmneziaWG)
   │                                    │
   │                                    ├─ VPN: 10.8.0.0/24
   │                                    └─ UI: 8888/tcp
   │
   └─[UI:8888/tcp]─────X─────► DOCKER-USER chain
                         │             │
                         │             ├─ ACCEPT from 10.8.0.0/24
                         │             └─ DROP from *
                         │
                     [VPN tunnel]
                         │
                         └────────────► http://10.8.0.1:8888
```

## Security Philosophy

### Defense in Depth
- **Layer 1**: SSH hardening (non-standard port, keys-only)
- **Layer 2**: UFW host firewall
- **Layer 3**: iptables DOCKER-USER chain (Docker bypass prevention)
- **Layer 4**: Container capabilities restriction

### Zero Trust for VPN UI
- **Bootstrap phase** (30-60 sec): UI exposed with bcrypt-protected random password
- **Production phase**: UI accessible ONLY from VPN subnet
- **Persistence**: Systemd ensures rules survive reboots

## Alternative Installation Methods

### From Specific Release
```bash
curl -fsSL https://github.com/JohnnyVBut/awg-easy-setup/releases/download/v1.0.0/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

### Clone Repository
```bash
git clone https://github.com/JohnnyVBut/awg-easy-setup.git
cd awg-easy-setup
sudo bash setup.sh
```

## Threat Model

### Protects Against:
✅ SSH brute-force attacks  
✅ Unauthorized VPN UI access  
✅ Port scanning (nmap)  
✅ Exploitation of UI vulnerabilities from Internet  
✅ VPN configuration leaks  

### Does NOT Protect Against:
❌ Compromised SSH private key  
❌ 0-day vulnerabilities in AmneziaWG kernel module  
❌ Physical server access  
❌ Attacks via compromised VPN client  
❌ DDoS on AmneziaWG port (54321/udp)  

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE)

## Support

- 🐛 [Report Issues](https://github.com/JohnnyVBut/awg-easy-setup/issues)
- 💬 [Discussions](https://github.com/JohnnyVBut/awg-easy-setup/discussions)

## Acknowledgments

- [AmneziaWG](https://github.com/amnezia-vpn/amneziawg) - Enhanced WireGuard protocol with traffic obfuscation
- [AmneziaVPN](https://amnezia.org/) - VPN client with AmneziaWG support
- [WireGuard](https://www.wireguard.com/) - Original fast, modern VPN protocol
- [awg-easy](https://github.com/gennadykataev/awg-easy) - Web UI for AmneziaWG

---

**⚠️ Security Notice:** This script modifies critical system settings. Always review the code before running on production servers.
