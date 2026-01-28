# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-01-28

### Added
- **Automated first VPN client creation** via AWG-Easy API
  - Automatic authentication with generated admin password
  - Creates "admin-device" client automatically
  - Generates one-time download link
  - Displays QR code directly in terminal
- **New dependencies** for QR code functionality:
  - `jq` - JSON parsing
  - `librsvg2-bin` - SVG to PNG conversion
  - `zbar-tools` - QR code decoding
  - `qrencode` - Terminal QR code display
- **Docker startup retry logic** for Ubuntu 24.04 compatibility
  - `systemctl reset-failed` before retry attempts
  - 3 retry attempts with 8-second delays
  - Graceful fallback with warnings

### Changed
- **Installation process** now has 12 steps instead of 11
- **Step numbering** updated throughout documentation
- **VPN client setup** is now fully automated (no manual Web UI interaction required)
- **Docker image reference** updated to `ghcr.io/johnnyvbut/awg-easy:latest`
- **Container environment variables** added:
  - `WG_ENABLE_ONE_TIME_LINKS=true`
  - `UI_CHART_TYPE=1`
  - `UI_TRAFFIC_STATS=true`
  - `LANG=en`
- **Volume permissions** changed to `root:root 755` (was `user:user 700`)

### Fixed
- Docker startup issues on Ubuntu 24.04 LTS
- Container restart loop on first installation
- Missing WG_DEFAULT_DNS environment variable
- AmneziaWG obfuscation parameters now properly configured

### Security
- One-time download links expire after single use
- API cookies automatically cleaned up after client creation
- All random passwords remain 24-char base64 (~144 bits entropy)

---

## [1.0.0] - 2026-01-26

### Initial Release
- Automated Ubuntu/Debian VPN server deployment
- SSH hardening (port 9722, keys-only, root disabled)
- AmneziaWG VPN container deployment
- Automatic Web UI lockdown to VPN-only access
- UFW + iptables DOCKER-USER firewall protection
- Systemd persistence for firewall rules
