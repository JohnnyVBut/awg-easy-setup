# API-Based Client Setup - New Features

## Overview

Starting from version 2.0, the setup script automatically creates your first VPN client using the AWG-Easy API. This eliminates the need for manual Web UI interaction during initial setup.

## What Happens Automatically

### 1. API Authentication
The script authenticates with the AWG-Easy container using the auto-generated admin password.

```bash
curl -X POST http://CONTAINER_IP:8888/api/session \
  -H "Content-Type: application/json" \
  -d '{"password":"AUTO_GENERATED_PASSWORD"}' \
  -c /tmp/awg-cookies.txt
```

### 2. Client Creation
Creates a VPN client named "admin-device" with no expiration date.

```bash
curl -X POST http://CONTAINER_IP:8888/api/wireguard/client \
  -H "Content-Type: application/json" \
  -d '{"name":"admin-device","expiredDate":""}' \
  -b /tmp/awg-cookies.txt
```

### 3. One-Time Link Generation
Generates a secure one-time download link for the configuration file.

```bash
curl -X POST \
  http://CONTAINER_IP:8888/api/wireguard/client/CLIENT_ID/generateOneTimeLink \
  -b /tmp/awg-cookies.txt
```

### 4. QR Code Display
Displays a scannable QR code directly in your terminal using:
- `rsvg-convert` - Converts SVG QR code to PNG
- `zbarimg` - Decodes QR code data
- `qrencode` - Renders QR code in terminal

## Installation Output Example

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
  http://94.103.88.147:8888/cnf/a1b2c3d4e5f6...

QR Code (scan with WireGuard mobile app):
█████████████████████████████████
███ ▄▄▄▄▄ █▀█ █▄▄▀▄█ ▄▄▄▄▄ ███
███ █   █ █▀▀▀ ▀ ▄ █ █   █ ███
███ █▄▄▄█ █▀ █▀▀ ██▄█ █▄▄▄█ ███
███▄▄▄▄▄▄▄█▄█ █ ▀▄█▄▄▄▄▄▄▄███
███ ▄  ▀▀▄▀ ▀▀█▄ ▀▄ ▀▀▄█ ▀▄███
███▀▀▄█▀ ▄ ██▀▄▀▀█▀█▄█▀ ▀█▄███
███ █▄ ▀▄▄▀▀▄▀▀▄▀▄▄█▀▀ ▀█ ▀███
███▄███▄▄▄█▀ ▀▀▄█ ▄▄▄ ███▄▀███
███ ▄▄▄▄▄ █▄▀█ ▄  █▄█ ▄▄ ▄▄███
███ █   █ █  █ ▀▄▄  ▄  █▄▄ ███
███ █▄▄▄█ █  ▀▄█▀█ ▀█ █▄ ▀████
███▄▄▄▄▄▄▄█▄█▄█▄███▄▄██▄██▄███
█████████████████████████████████

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> TEMPORARY Web UI access is OPEN to the Internet.
    You can also access Web UI at:
    URL:  http://94.103.88.147:8888
    User: admin
    Pass: Q0c4B7+htfYFfVXPwn6LhCKLRDJe553n

Press ENTER to lock the Web UI to VPN-only access...
```

## Security Considerations

### One-Time Download Links
- **Expires after first download** - the link becomes invalid immediately after use
- **Time-limited** - links may expire after a certain period (configured in container)
- **Non-guessable** - uses cryptographically random tokens
- **Requires `WG_ENABLE_ONE_TIME_LINKS=true`** in container configuration

### API Session Security
- Cookies stored in `/tmp/awg-cookies.txt` during setup
- **Automatically deleted** after client creation completes
- Uses bcrypt-hashed password authentication
- Session limited to setup script execution time

### QR Code Privacy
- QR code displayed **only in terminal** (not saved to disk)
- Temporary PNG file deleted immediately after display
- Contains full WireGuard configuration (keep terminal output secure!)

## Fallback Behavior

If API-based client creation fails (container not ready, network issue, etc.), the script continues with a warning:

```
⚠ WARNING: API authentication failed
You will need to create VPN client manually via Web UI
```

The script will still:
1. Open Web UI temporarily
2. Display admin credentials
3. Wait for manual client creation
4. Lock Web UI after confirmation

## Dependencies

The following packages are automatically installed:

- **jq** - JSON parsing for API responses
- **librsvg2-bin** - SVG to PNG conversion for QR codes
- **zbar-tools** - QR code data extraction
- **qrencode** - Terminal-based QR code rendering

## Manual API Usage

You can manually create additional clients using the same API:

```bash
# Authenticate
curl -X POST http://10.8.0.1:8888/api/session \
  -H "Content-Type: application/json" \
  -d '{"password":"YOUR_ADMIN_PASSWORD"}' \
  -c cookies.txt

# Create client
curl -X POST http://10.8.0.1:8888/api/wireguard/client \
  -H "Content-Type: application/json" \
  -d '{"name":"my-laptop","expiredDate":"2027-12-31"}' \
  -b cookies.txt

# List clients
curl -sS -b cookies.txt \
  -H 'Accept: application/json' \
  'http://10.8.0.1:8888/api/wireguard/client' | jq '.'

# Get specific client QR code
curl -sS -b cookies.txt \
  'http://10.8.0.1:8888/api/wireguard/client/CLIENT_ID/qrcode.svg' \
  > qrcode.svg
```

For full API documentation, see [API_ENDPOINTS_COMPLETE.md](API_ENDPOINTS_COMPLETE.md).

## Troubleshooting

### QR Code Not Displaying
If QR code generation fails:
```
(QR code generation failed - install missing tools or download config manually)
```

**Solution:** Install missing dependencies manually:
```bash
sudo apt install -y librsvg2-bin zbar-tools qrencode
```

### API Authentication Failed
**Possible causes:**
- Container not fully initialized (wait 10-15 seconds and retry)
- Network connectivity issue between host and container
- Incorrect password hash generation

**Solution:** Create client manually via Web UI as shown in the fallback output.

### One-Time Link Already Used
**Symptom:** 404 error when accessing `/cnf/` link

**Solution:** Generate a new link via Web UI:
1. Connect to VPN
2. Access http://10.8.0.1:8888
3. Go to client settings
4. Click "Generate One-Time Link"

---

**Note:** All API interactions occur over HTTP on the local Docker network (172.17.0.0/16). External access to the API is blocked by firewall rules after initial setup.
