# Client Configuration Guide

[Русская версия](../ru/CLIENTS.md) | **English**

## Table of Contents
- [About AmneziaWG](#about-amneziawg)
- [Supported Platforms](#supported-platforms)
- [Installing Amnezia Client](#installing-amnezia-client)
- [Importing Configuration](#importing-configuration)
- [Platform-Specific Guides](#platform-specific-guides)
- [Troubleshooting](#troubleshooting)

## About AmneziaWG

**AmneziaWG** is an enhanced version of WireGuard with additional traffic obfuscation features:

- **Based on WireGuard**: Same fast, secure cryptography
- **Traffic Obfuscation**: Makes VPN traffic harder to detect and block
- **DPI Resistance**: Bypasses Deep Packet Inspection
- **Compatible**: Uses standard WireGuard client on some platforms

### When to Use AmneziaWG

✅ **Use AmneziaWG when:**
- In countries with VPN blocking (China, Iran, Russia, etc.)
- ISP throttles VPN traffic
- Need maximum censorship resistance

⚠️ **Use Standard WireGuard when:**
- No censorship/blocking concerns
- Maximum performance needed
- Simpler setup preferred

## Supported Platforms

| Platform | Client | Status |
|----------|--------|--------|
| **Android** | AmneziaVPN | ✅ Recommended |
| **iOS** | AmneziaVPN | ✅ Recommended |
| **Windows** | AmneziaVPN | ✅ Recommended |
| **macOS** | AmneziaVPN | ✅ Recommended |
| **Linux** | amneziawg-tools | ✅ Command line |

## Installing Amnezia Client

### Android

**Method 1: Google Play (Recommended)**
1. Open [Google Play Store](https://play.google.com/store/apps/details?id=org.amnezia.vpn)
2. Search for "AmneziaVPN"
3. Tap "Install"
4. Open app after installation

**Method 2: APK Direct Download**
```bash
# From official GitHub releases:
# https://github.com/amnezia-vpn/amnezia-client/releases

# Download latest .apk file
# Enable "Install from unknown sources" in Settings
# Install the APK
```

### iOS

1. Open [App Store](https://apps.apple.com/app/amneziavpn/id1600529900)
2. Search for "AmneziaVPN"
3. Tap "Get"
4. Authenticate with Face ID/Touch ID
5. Open app after installation

### Windows

**Download from official website:**

1. Visit [https://amnezia.org/](https://amnezia.org/)
2. Click "Download" → Select "Windows"
3. Run the installer `.exe` file
4. Follow installation wizard
5. Launch AmneziaVPN from Start Menu

**Or download from GitHub:**
```powershell
# Visit: https://github.com/amnezia-vpn/amnezia-client/releases
# Download: AmneziaVPN_x.x.x_windows_x64.exe
```

### macOS

**Method 1: Official Website**
1. Visit [https://amnezia.org/](https://amnezia.org/)
2. Click "Download" → Select "macOS"
3. Open the `.dmg` file
4. Drag AmneziaVPN to Applications folder
5. Launch from Applications

**Method 2: Homebrew**
```bash
brew install --cask amneziavpn
```

### Linux (Ubuntu/Debian)

**Install amneziawg-tools (command line):**

```bash
# Add Amnezia repository
sudo add-apt-repository ppa:amnezia/ppa
sudo apt update

# Install amneziawg
sudo apt install amneziawg amneziawg-tools

# Verify installation
awg --version
```

**Or use GUI client:**
```bash
# Download .AppImage from GitHub
wget https://github.com/amnezia-vpn/amnezia-client/releases/download/vX.X.X/AmneziaVPN_x.x.x_linux_amd64.AppImage

# Make executable
chmod +x AmneziaVPN_*.AppImage

# Run
./AmneziaVPN_*.AppImage
```

## Importing Configuration

### Method 1: QR Code (Mobile)

**On Server:**
1. Connect to VPN (if UI is locked)
2. Open `http://10.8.0.1:8888` in browser
3. Login with credentials from setup script
4. Click "Add Client" → Enter name
5. Click "Show QR Code"

**On Mobile Device:**
1. Open AmneziaVPN app
2. Tap "+" or "Add Connection"
3. Select "Scan QR Code"
4. Point camera at QR code on screen
5. Connection auto-imports

### Method 2: Configuration File (Desktop)

**On Server:**
1. Connect to VPN or temporarily open UI
2. Navigate to `http://10.8.0.1:8888`
3. Click "Add Client" → Enter name
4. Click "Download Config"
5. Save `.conf` file (e.g., `laptop-client.conf`)

**On Desktop:**

**AmneziaVPN GUI:**
1. Open AmneziaVPN
2. Click "Add Server"
3. Select "Import from file"
4. Browse to `.conf` file
5. Click "Import"

**Linux Command Line:**
```bash
# Copy config to /etc/amneziawg/
sudo cp laptop-client.conf /etc/amneziawg/awg0.conf

# Start tunnel
sudo awg-quick up awg0

# Verify
sudo awg show
ip addr show awg0

# Stop tunnel
sudo awg-quick down awg0
```

### Method 3: Manual Entry (Advanced)

Open the `.conf` file in text editor:

```ini
[Interface]
PrivateKey = <YOUR_PRIVATE_KEY>
Address = 10.8.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = YOUR_SERVER_IP:54321
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25

# AmneziaWG specific parameters
Jc = 5
Jmin = 50
Jmax = 1000
S1 = 100
S2 = 200
H1 = 1234567890
H2 = 9876543210
H3 = 1122334455
H4 = 5544332211
```

**In AmneziaVPN:**
1. Click "Add Server"
2. Select "Enter manually"
3. Copy-paste each field
4. Save connection

## Platform-Specific Guides

### Android Detailed Setup

1. **Install AmneziaVPN** from Play Store
2. **Open app** → Tap "Add Connection"
3. **Scan QR code** from web UI
4. **Name connection** (e.g., "Home VPN")
5. **Configure options:**
   - Auto-connect: ON (optional)
   - Kill switch: ON (recommended)
6. **Tap "Connect"**
7. **Grant VPN permission** when prompted
8. **Verify connection:**
   - Check for key icon in status bar
   - Visit [https://whatismyipaddress.com/](https://whatismyipaddress.com/)
   - IP should match your VPN server

**Battery Optimization:**
```
Settings → Apps → AmneziaVPN → Battery
→ Set to "Unrestricted" to prevent disconnections
```

### iOS Detailed Setup

1. **Install AmneziaVPN** from App Store
2. **Open app** → Tap "+"
3. **Scan QR code** or import file
4. **Name profile** (e.g., "My Server")
5. **Tap "Add VPN Configuration"**
6. **Face ID/Touch ID** to authorize
7. **Enable connection** with toggle
8. **Verify:** VPN icon appears in status bar

**Always-On VPN (iOS 15+):**
```
Settings → General → VPN & Device Management
→ VPN → Connect On Demand → Enable
```

### Windows Detailed Setup

1. **Install AmneziaVPN** (see above)
2. **Launch application**
3. **Click "Add Server"**
4. **Select import method:**
   - "Import from file" → Browse to `.conf`
   - "Scan QR code" → Use phone camera
5. **Click "Connect"**
6. **Grant firewall permissions** if prompted
7. **Verify connection:**
   - Green checkmark in app
   - Visit [ipinfo.io](https://ipinfo.io)

**Windows Firewall:**
```powershell
# If connection blocked, allow AmneziaVPN:
New-NetFirewallRule -DisplayName "AmneziaVPN" `
  -Direction Inbound -Action Allow `
  -Program "C:\Program Files\AmneziaVPN\AmneziaVPN.exe"
```

### macOS Detailed Setup

1. **Install AmneziaVPN** (see above)
2. **Open from Applications**
3. **Grant permissions:**
   - System Preferences → Security & Privacy
   - Allow "AmneziaVPN" to modify network settings
4. **Import configuration:**
   - Drag `.conf` file into app window
   - OR: File → Import Configuration
5. **Click "Connect"**
6. **Enter password** when prompted (macOS user password)
7. **Verify:** Menu bar shows VPN status

**Troubleshooting macOS Permissions:**
```bash
# Reset VPN permissions if needed
sudo rm /Library/Preferences/SystemConfiguration/com.apple.networkextension.plist
# Restart Mac
```

### Linux Command Line Setup

**Using awg-quick:**

```bash
# 1. Copy config from server
scp -P 9722 admino@SERVER_IP:~/client.conf ~/client.conf

# 2. Install (if not done)
sudo apt install amneziawg amneziawg-tools

# 3. Move to system directory
sudo cp ~/client.conf /etc/amneziawg/awg0.conf
sudo chmod 600 /etc/amneziawg/awg0.conf

# 4. Start VPN
sudo awg-quick up awg0

# 5. Verify
sudo awg show
# Should show interface, peer, latest handshake

# Test connectivity
ping 10.8.0.1
curl https://ipinfo.io/ip
# Should show VPN server IP

# 6. Stop VPN
sudo awg-quick down awg0
```

**Auto-start on boot:**

```bash
# Enable systemd service
sudo systemctl enable awg-quick@awg0.service
sudo systemctl start awg-quick@awg0.service

# Check status
systemctl status awg-quick@awg0
```

**Manual control:**

```bash
# Create interface
sudo ip link add dev awg0 type amneziawg
sudo ip address add dev awg0 10.8.0.2/24
sudo awg setconf awg0 /etc/amneziawg/awg0.conf
sudo ip link set up dev awg0

# Add routing
sudo ip route add default dev awg0

# Remove interface
sudo ip link delete dev awg0
```

## Advanced Configuration

### Split Tunneling

**Only route specific traffic through VPN:**

Edit `.conf` file:
```ini
[Interface]
PrivateKey = ...
Address = 10.8.0.2/32

[Peer]
PublicKey = ...
Endpoint = SERVER_IP:54321
# Only route work network through VPN:
AllowedIPs = 192.168.1.0/24, 10.0.0.0/8
# NOT: 0.0.0.0/0
```

### DNS Configuration

**Use custom DNS servers:**

```ini
[Interface]
PrivateKey = ...
Address = 10.8.0.2/32
# Cloudflare DNS:
DNS = 1.1.1.1, 1.0.0.1
# OR Google DNS:
# DNS = 8.8.8.8, 8.8.4.4
# OR Quad9:
# DNS = 9.9.9.9, 149.112.112.112
```

### Connection Persistence

**Keepalive for NAT traversal:**

```ini
[Peer]
...
PersistentKeepalive = 25
# Send keepalive every 25 seconds
# Prevents NAT timeout (usually 30-60s)
```

### IPv6 Support

**If server has IPv6:**

```ini
[Interface]
Address = 10.8.0.2/32, fd00::2/128

[Peer]
AllowedIPs = 0.0.0.0/0, ::/0
```

## Troubleshooting

### Connection Fails

**Symptoms:** "Handshake failed" or timeout

**Diagnosis:**
```bash
# On client (Linux):
sudo awg show
# Check "latest handshake" - should be recent

# On server:
docker logs awg-easy | tail -50
# Look for connection attempts
```

**Solutions:**

1. **Verify server reachable:**
   ```bash
   ping YOUR_SERVER_IP
   nc -zvu YOUR_SERVER_IP 54321
   ```

2. **Check server firewall:**
   ```bash
   # On server:
   sudo ufw status | grep 54321
   # Should show: 54321/udp ALLOW Anywhere
   ```

3. **Verify config:**
   - Endpoint IP correct?
   - Port 54321 correct?
   - Keys copied correctly?

4. **Check client firewall:**
   - Windows: Allow AmneziaVPN in firewall
   - macOS: Grant network permissions
   - Linux: Check iptables

### Connected but No Internet

**Symptoms:** VPN shows connected, but websites don't load

**Diagnosis:**
```bash
# Can you reach VPN gateway?
ping 10.8.0.1

# Can you reach Internet via VPN?
ping 1.1.1.1

# DNS working?
nslookup google.com
```

**Solutions:**

1. **DNS issue:**
   ```ini
   # Add DNS to config:
   [Interface]
   DNS = 1.1.1.1
   ```

2. **Routing issue:**
   ```bash
   # On client (Linux):
   ip route show
   # Should have: default dev awg0
   
   # If not, restart:
   sudo awg-quick down awg0
   sudo awg-quick up awg0
   ```

3. **Server IP forwarding:**
   ```bash
   # On server:
   docker exec awg-easy sysctl net.ipv4.ip_forward
   # Should be: 1
   
   # If not:
   docker restart awg-easy
   ```

### Slow Speed

**Test bandwidth:**
```bash
# Install speedtest
curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
sudo apt install speedtest

# Test without VPN
speedtest

# Connect to VPN
sudo awg-quick up awg0

# Test with VPN
speedtest
```

**Optimizations:**

1. **MTU tuning:**
   ```ini
   [Interface]
   MTU = 1420
   # Try: 1380, 1340 if still slow
   ```

2. **Reduce encryption overhead** (not recommended for security):
   ```bash
   # Use ed25519 keys (already done)
   # Ensure modern CPU with AES-NI support
   ```

3. **Check server CPU:**
   ```bash
   # On server:
   htop
   # If CPU maxed, upgrade server
   ```

### Frequent Disconnections

**Symptoms:** VPN drops every few minutes

**Solutions:**

1. **Increase keepalive:**
   ```ini
   [Peer]
   PersistentKeepalive = 15
   # Try: 15, 10, 5
   ```

2. **Disable battery optimization (mobile):**
   - Android: Settings → Battery → Unrestricted
   - iOS: Should not be issue

3. **Check NAT timeout:**
   ```bash
   # Some ISPs have short NAT timeout
   # PersistentKeepalive must be LESS than timeout
   # Typical: 30-60 seconds
   ```

### Can't Access Web UI After Lockdown

**Symptoms:** `curl http://10.8.0.1:8888` times out

**Solution:**

1. **Verify connected to VPN:**
   ```bash
   ip addr show awg0
   # Should show: inet 10.8.0.2/32
   ```

2. **Check VPN gateway:**
   ```bash
   ping 10.8.0.1
   # Should respond
   ```

3. **Verify UI is running:**
   ```bash
   # SSH to server:
   ssh -p 9722 admino@SERVER_IP
   
   # Check container:
   docker ps | grep awg-easy
   docker logs awg-easy
   ```

4. **Temporarily unlock (from server):**
   ```bash
   # Allow your VPN client IP:
   sudo iptables -I DOCKER-USER 1 -s 10.8.0.2 -p tcp --dport 8888 -j ACCEPT
   
   # After finished, remove:
   sudo iptables -D DOCKER-USER -s 10.8.0.2 -p tcp --dport 8888 -j ACCEPT
   ```

## Multiple Devices

**Best practices:**

1. **Create separate config for each device:**
   - laptop-client.conf
   - phone-client.conf
   - tablet-client.conf

2. **Benefits:**
   - Revoke individual devices if compromised
   - Track which device is connected
   - Different IPs for each (10.8.0.2, .3, .4, etc.)

3. **How to create:**
   ```bash
   # In web UI:
   # Click "Add Client" → Name: "Laptop"
   # Click "Add Client" → Name: "Phone"
   # Each gets unique keys and IP
   ```

## Security Best Practices

### Protect Configuration Files

**Desktop:**
```bash
# Restrict permissions:
chmod 600 ~/vpn-config.conf

# Encrypt if storing on cloud:
gpg --symmetric --cipher-algo AES256 vpn-config.conf
# Store: vpn-config.conf.gpg
# Delete original: shred -vfz vpn-config.conf
```

**Mobile:**
- Don't screenshot QR codes
- Delete downloaded configs after import
- Use device encryption

### Revoke Compromised Clients

**If device lost/stolen:**

1. **Access web UI** from another VPN-connected device
2. **Navigate to clients list**
3. **Click "Delete"** on compromised client
4. **Confirm deletion**
5. **Restart server** (optional, immediate effect):
   ```bash
   docker restart awg-easy
   ```

### Regular Key Rotation

**Monthly rotation recommended:**

```bash
# Create new client
# Delete old client
# Update all devices with new config
```

## Additional Resources

- [AmneziaVPN Official Site](https://amnezia.org/)
- [AmneziaWG GitHub](https://github.com/amnezia-vpn/amneziawg)
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
