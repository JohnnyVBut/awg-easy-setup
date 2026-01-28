#!/bin/bash
set -euo pipefail

# ========= Settings =========
SSH_PORT=9722
SSHD_CONFIG="/etc/ssh/sshd_config"
DEFAULT_USER="admino"
WG_PORT=54321                 # WireGuard UDP port (exposed)
AWG_PORT=8888                 # awg-easy Web UI port
VPN_SUBNET="10.8.8.0/24"      # Web UI allowed only from this subnet after bootstrap
CONTAINER_NAME="awg-easy"
IMAGE_REF="ghcr.io/johnnyvbut/awg-easy:latest"

# ========= Preconditions =========
if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root (or via sudo)."
  exit 1
fi
command -v apt >/dev/null || { echo "This script expects apt (Ubuntu/Debian)."; exit 1; }

# ========= 1) Update & upgrade =========
echo "[1/12] Updating packages..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt -y upgrade

# ========= 2) Install Docker (official repo), OpenSSH, UFW, tools =========
echo "[2/12] Installing Docker (official repo), OpenSSH, UFW, and tools..."
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

# software-properties-common may not exist on Debian
apt install -y software-properties-common 2>/dev/null || true

apt remove -y docker docker-engine docker.io containerd runc || true

install -m 0755 -d /etc/apt/keyrings

# Detect OS type (Ubuntu or Debian)
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  OS_ID="${ID}"
  OS_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs)}"
else
  OS_ID="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
  OS_CODENAME="$(lsb_release -cs)"
fi

# Download appropriate GPG key if not exists
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  if [[ "$OS_ID" == "debian" ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  fi
fi
chmod a+r /etc/apt/keyrings/docker.gpg

# Always recreate repository file with correct OS
if [[ "$OS_ID" == "debian" ]]; then
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${OS_CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null
else
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${OS_CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt install -y openssh-server ufw python3 python3-pip git jq vim htop unzip zip apache2-utils dnsutils

# Install QR code dependencies
echo "[2/12] Installing QR code tools..."
apt install -y librsvg2-bin zbar-tools qrencode

# Install sudo if not present (Debian)
if ! command -v sudo >/dev/null 2>&1; then
  echo "[2/12] Installing sudo (not present on clean Debian)..."
  apt install -y sudo
fi

# Enable services
systemctl enable docker.socket
systemctl enable docker
systemctl enable ssh

# Start Docker with retry logic (Ubuntu 24 needs this)
echo "[2/12] Starting Docker daemon..."
MAX_ATTEMPTS=3
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "→ Starting Docker (attempt $ATTEMPT/$MAX_ATTEMPTS)..."

  # Reset failed state from previous attempts
  systemctl reset-failed docker.socket 2>/dev/null || true
  systemctl reset-failed docker 2>/dev/null || true

  systemctl start docker.socket || true
  sleep 3
  systemctl start docker || true
  sleep 5

  if systemctl is-active --quiet docker; then
    echo "✓ Docker started successfully"
    break
  fi

  echo "⚠ Docker failed to start, will retry..."
done

if ! systemctl is-active --quiet docker; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠ WARNING: Docker failed to start after $MAX_ATTEMPTS attempts"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  journalctl -xeu docker.service --no-pager -n 15
  echo ""
  echo "Will retry before running container in section 9..."
  echo ""
fi

systemctl start ssh

# ========= 3) Create sudo user (10s prompt) =========
echo "[3/12] Creating a sudo user (you have 10 seconds to type a name)..."
read -r -t 10 -p "Enter new username (10s timeout): " NEWUSER || true
if [[ -z "${NEWUSER:-}" ]]; then
  NEWUSER="$DEFAULT_USER"
  echo "No input. Will create user: $NEWUSER"
fi

USER_ALREADY_EXISTED=false
if id "$NEWUSER" &>/dev/null; then
  USER_ALREADY_EXISTED=true
  echo "User $NEWUSER already exists — skipping creation."
else
  USER_PASS="$(openssl rand -base64 24 | tr -d '\n')"
  useradd -m -s /bin/bash "$NEWUSER"
  echo "${NEWUSER}:${USER_PASS}" | chpasswd

  # Determine correct sudo group (Debian uses 'sudo', some systems use 'wheel')
  if getent group sudo >/dev/null; then
    SUDO_GROUP="sudo"
  elif getent group wheel >/dev/null; then
    SUDO_GROUP="wheel"
  else
    echo "WARNING: No sudo/wheel group found. User will not have sudo access."
    SUDO_GROUP=""
  fi

  if [[ -n "$SUDO_GROUP" ]]; then
    usermod -aG "$SUDO_GROUP,docker" "$NEWUSER"
    echo "User $NEWUSER created and added to groups: $SUDO_GROUP,docker."
  else
    usermod -aG docker "$NEWUSER"
    echo "User $NEWUSER created and added to group: docker."
  fi
fi

HOME_DIR="$(eval echo "~$NEWUSER")"

# ========= 4) SSH keys for new user + import root's authorized_keys =========
echo "[4/12] Generating SSH keys and importing /root/.ssh/authorized_keys..."
install -d -m 700 -o "$NEWUSER" -g "$NEWUSER" "$HOME_DIR/.ssh"
if [[ ! -f "$HOME_DIR/.ssh/id_ed25519" ]]; then
  sudo -u "$NEWUSER" ssh-keygen -t ed25519 -N "" -f "$HOME_DIR/.ssh/id_ed25519" >/dev/null
fi

touch "$HOME_DIR/.ssh/authorized_keys"
chmod 600 "$HOME_DIR/.ssh/authorized_keys"
chown "$NEWUSER:$NEWUSER" "$HOME_DIR/.ssh/authorized_keys"

PUBKEY_CONTENT="$(cat "$HOME_DIR/.ssh/id_ed25519.pub")"
grep -qxF "$PUBKEY_CONTENT" "$HOME_DIR/.ssh/authorized_keys" || echo "$PUBKEY_CONTENT" >> "$HOME_DIR/.ssh/authorized_keys"

ROOT_KEYS_IMPORTED="no"
ROOT_KEYS_SRC="/root/.ssh/authorized_keys"
if [[ -f "$ROOT_KEYS_SRC" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    grep -qxF "$line" "$HOME_DIR/.ssh/authorized_keys" || echo "$line" >> "$HOME_DIR/.ssh/authorized_keys"
  done < "$ROOT_KEYS_SRC"
  chown "$NEWUSER:$NEWUSER" "$HOME_DIR/.ssh/authorized_keys"
  chmod 600 "$HOME_DIR/.ssh/authorized_keys"
  ROOT_KEYS_IMPORTED="yes"
fi

# ========= 5) Random password for root (SSH root login stays disabled) =========
echo "[5/12] Setting a random password for root (SSH login for root stays disabled)..."
ROOT_PASS="$(openssl rand -base64 24 | tr -d '\n')"
echo "root:${ROOT_PASS}" | chpasswd

# ========= 6) Harden SSH: public-key only, no passwords, no root, custom port =========
echo "[6/12] Hardening SSH (port ${SSH_PORT}, disable passwords, root login off)..."
backup="${SSHD_CONFIG}.bak"; [[ -f "$backup" ]] || cp "$SSHD_CONFIG" "$backup"

apply_sshd_conf() {
  local k="$1" v="$2"
  if grep -qE "^[#\s]*${k}\b" "$SSHD_CONFIG"; then
    sed -i "s|^[#\s]*${k}.*|${k} ${v}|g" "$SSHD_CONFIG"
  else
    printf "%s %s\n" "$k" "$v" >> "$SSHD_CONFIG"
  fi
}
apply_sshd_conf "Port" "$SSH_PORT"
apply_sshd_conf "PermitRootLogin" "no"
apply_sshd_conf "PasswordAuthentication" "no"
apply_sshd_conf "KbdInteractiveAuthentication" "no"
apply_sshd_conf "ChallengeResponseAuthentication" "no"
apply_sshd_conf "PubkeyAuthentication" "yes"
apply_sshd_conf "AuthenticationMethods" "publickey"
apply_sshd_conf "PermitEmptyPasswords" "no"
apply_sshd_conf "UsePAM" "yes"

for f in /etc/ssh/sshd_config.d/*.conf; do
  [[ -f "$f" ]] || continue
  sed -i 's/^[[:space:]]*PasswordAuthentication[[:space:]]\+yes/PasswordAuthentication no/g' "$f" || true
  sed -i 's/^[[:space:]]*KbdInteractiveAuthentication[[:space:]]\+yes/KbdInteractiveAuthentication no/g' "$f" || true
  sed -i 's/^[[:space:]]*ChallengeResponseAuthentication[[:space:]]\+yes/ChallengeResponseAuthentication no/g' "$f" || true
done

sshd -t
echo "[6/12] Effective SSH options (sanity check):"
sshd -T | egrep 'port|passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|pubkeyauthentication|authenticationmethods|permitrootlogin' || true

systemctl restart ssh

# ========= 7) UFW: expose SSH & WG; do NOT open UI yet =========
echo "[7/12] Configuring UFW (allow SSH ${SSH_PORT}/tcp and WG ${WG_PORT}/udp)..."
ufw allow "${SSH_PORT}/tcp" || true
ufw allow "${WG_PORT}/udp" || true
if ! ufw status | grep -q "Status: active"; then
  echo "y" | ufw enable || true
fi
ufw reload || true

# ========= 8) Run awg-easy (publish UI) & TEMPORARILY open UI via UFW =========
echo "[8/12] Running awg-easy container (publishing UI ${AWG_PORT}/tcp)..."

# Final check that Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is still not running. Please investigate:"
  journalctl -xeu docker.service --no-pager -n 20
  exit 1
fi

AWG_PASS="$(openssl rand -base64 24 | tr -d '\n')"
PASSWORD_HASH="$(htpasswd -nbB admin "$AWG_PASS" | cut -d: -f2)"  # bcrypt (cost=5)

WG_HOST="$(curl -fsS https://api.ipify.org || true)"
[[ -z "$WG_HOST" ]] && WG_HOST="$(dig +short myip.opendns.com @resolver1.opendns.com || true)"
[[ -z "$WG_HOST" ]] && WG_HOST="$(curl -fsS https://ifconfig.me || true)"
[[ -z "$WG_HOST" ]] && WG_HOST="0.0.0.0"

HOST_CONF_DIR="$HOME_DIR/.awg-easy"
install -d -m 755 "$HOST_CONF_DIR"
chown root:root "$HOST_CONF_DIR"

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

docker run -d \
  --name="$CONTAINER_NAME" \
  -e LANG=en \
  -e WG_HOST="$WG_HOST" \
  -e PASSWORD_HASH="$PASSWORD_HASH" \
  -e WG_ENABLE_ONE_TIME_LINKS=true \
  -e UI_CHART_TYPE=1 \
  -e UI_TRAFFIC_STATS=true \
  -e PORT="$AWG_PORT" \
  -e WG_PORT="$WG_PORT" \
  -e WG_DEFAULT_DNS=1.1.1.1,8.8.8.8 \
  -e JC=6 \
  -e JMIN=10 \
  -e JMAX=50 \
  -e S1=64 \
  -e S2=67 \
  -e S3=17 \
  -e S4=4 \
  -e H1=221138202-537563446 \
  -e H2=1824677785-1918284606 \
  -e H3=2058490965-2098228430 \
  -e H4=2114920036-2134209753 \
  -e I1='<b 0x084481800001000300000000077469636b65747306776964676574096b696e6f706f69736b0272750000010001c00c0005000100000039001806776964676574077469636b6574730679616e646578c025c0390005000100000039002b1765787465726e616c2d7469636b6574732d776964676574066166697368610679616e646578036e657400c05d000100010000001c000457fafe25>' \
  -e I2= \
  -e I3= \
  -e I4= \
  -e I5= \
  -e ITIME=0 \
  -v "$HOST_CONF_DIR:/etc/wireguard" \
  -v "$HOST_CONF_DIR:/etc/amnezia/amneziawg" \
  -p "${WG_PORT}:${WG_PORT}/udp" \
  -p "${AWG_PORT}:${AWG_PORT}/tcp" \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --device=/dev/net/tun:/dev/net/tun \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --sysctl="net.ipv4.ip_forward=1" \
  --restart unless-stopped \
  "$IMAGE_REF"

# Wait for container to start and stabilize
echo "[8/12] Waiting for container to start..."
sleep 5

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "ERROR: Container failed to start. Checking logs..."
  docker logs "$CONTAINER_NAME"
  echo
  echo "Please check if AmneziaWG kernel module is installed:"
  echo "  lsmod | grep amneziawg"
  echo
  echo "If not installed, run:"
  echo "  apt install -y linux-headers-\$(uname -r) build-essential git"
  echo "  cd /tmp && git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git"
  echo "  cd amneziawg-linux-kernel-module/src && make && make install && modprobe amneziawg"
  exit 1
fi

# TEMPORARILY open UI via UFW (note: Docker may bypass UFW; we'll enforce DOCKER-USER later)
ufw allow "${AWG_PORT}/tcp" || true
ufw reload || true

CONTAINER_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" || true)"

# ========= 9) Create first VPN client via API =========
echo "[9/12] Creating first VPN client via API..."

COOKIES_FILE="/tmp/awg-cookies.txt"
API_URL="http://${CONTAINER_IP}:${AWG_PORT}"

# Wait for API to be ready
sleep 3

# Authenticate
echo "→ Authenticating..."
AUTH_RESPONSE=$(curl -sS -X POST "${API_URL}/api/session" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${AWG_PASS}\"}" \
  -c "$COOKIES_FILE" 2>/dev/null || echo "")

if ! echo "$AUTH_RESPONSE" | grep -q '"success":true'; then
  echo "⚠ WARNING: API authentication failed"
  echo "You will need to create VPN client manually via Web UI"
else
  echo "✓ Authenticated successfully"

  # Create client
  echo "→ Creating VPN client..."
  CREATE_RESPONSE=$(curl -sS -X POST "${API_URL}/api/wireguard/client" \
    -H "Content-Type: application/json" \
    -d '{"name":"admin-device","expiredDate":""}' \
    -b "$COOKIES_FILE" 2>/dev/null || echo "")

  if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    echo "✓ Client created successfully"
    sleep 2

    # Get client ID
    CLIENTS=$(curl -sS -b "$COOKIES_FILE" \
      -H 'Accept: application/json' \
      "${API_URL}/api/wireguard/client" 2>/dev/null || echo "[]")

    CLIENT_ID=$(echo "$CLIENTS" | jq -r '.[0].id' 2>/dev/null || echo "")

    if [[ -n "$CLIENT_ID" && "$CLIENT_ID" != "null" ]]; then
      echo "✓ Client ID: $CLIENT_ID"

      # Generate one-time link
      echo "→ Generating one-time download link..."
      GENERATE_RESPONSE=$(curl -sS -X POST \
        "${API_URL}/api/wireguard/client/${CLIENT_ID}/generateOneTimeLink" \
        -b "$COOKIES_FILE" 2>/dev/null || echo "")

      if echo "$GENERATE_RESPONSE" | grep -q '"success":true'; then
        echo "✓ One-time link generated"
        sleep 2

        # Get updated client info with one-time link
        CLIENTS=$(curl -sS -b "$COOKIES_FILE" \
          "${API_URL}/api/wireguard/client" 2>/dev/null || echo "[]")

        ONE_TIME_LINK=$(echo "$CLIENTS" | jq -r '.[0].oneTimeLink' 2>/dev/null || echo "")

        if [[ -n "$ONE_TIME_LINK" && "$ONE_TIME_LINK" != "null" ]]; then
          DOWNLOAD_URL="http://${WG_HOST}:${AWG_PORT}/cnf/${ONE_TIME_LINK}"

          # Function to display QR code in terminal
          display_qr_code() {
            local client_id="$1"
            local url="${API_URL}/api/wireguard/client/${client_id}/qrcode.svg"
            local tmp=$(mktemp --suffix=.png)

            if curl -sS -b "$COOKIES_FILE" "$url" 2>/dev/null \
              | rsvg-convert -f png -w 800 -h 800 > "$tmp" 2>/dev/null; then

              if zbarimg --raw -q "$tmp" 2>/dev/null \
                | qrencode -t ANSIUTF8 -l L -m 0 -s 1 2>/dev/null; then
                rm -f "$tmp"
                return 0
              fi
            fi

            rm -f "$tmp"
            echo "  (QR code generation failed - install missing tools or download config manually)"
            return 1
          }

          echo ""
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "✓ FIRST VPN CLIENT CREATED!"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo ""
          echo "Download config file for desktop PC (ONE-TIME LINK - expires after download):"
          echo "  $DOWNLOAD_URL"
          echo ""
          echo "Or scan QR Code  with AmneziaWG mobile app:"
          display_qr_code "$CLIENT_ID"
          echo ""
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo ""
        fi
      fi
    fi
  fi
fi

# Clean up cookies
rm -f "$COOKIES_FILE"

echo
echo ">>> TEMPORARY Web UI access is OPEN to the Internet."
echo "    You can also access Web UI at:"
echo "    URL:  http://${WG_HOST}:${AWG_PORT}"
echo "    User: admin"
echo "    Pass: ${AWG_PASS}"
echo
read -r -p "Press ENTER to lock the Web UI to VPN-only access... " _

# ========= 10) LOCK Web UI to VPN-only: UFW + DOCKER-USER chain =========
echo "[10/12] Locking the Web UI to VPN-only (${VPN_SUBNET})..."

# UFW: allow from VPN subnet, deny everyone else
ufw delete allow "${AWG_PORT}/tcp" >/dev/null 2>&1 || true
ufw allow from "${VPN_SUBNET}" to any port "${AWG_PORT}" proto tcp || true
ufw deny  "${AWG_PORT}/tcp" || true
ufw reload || true

# Enforce with iptables DOCKER-USER (Docker can bypass UFW otherwise)
apply_docker_user_lock() {
  local port="$1" subnet="$2"
  # Ensure chain exists
  iptables -N DOCKER-USER 2>/dev/null || true

  # Remove Docker's default RETURN rule (critical for blocking to work)
  while iptables -C DOCKER-USER -j RETURN 2>/dev/null; do
    iptables -D DOCKER-USER -j RETURN
  done

  # Remove existing rules for this port to avoid duplicates
  while iptables -C DOCKER-USER -p tcp --dport "$port" -j DROP 2>/dev/null; do
    iptables -D DOCKER-USER -p tcp --dport "$port" -j DROP
  done
  while iptables -C DOCKER-USER -p tcp --dport "$port" -s "$subnet" -j ACCEPT 2>/dev/null; do
    iptables -D DOCKER-USER -p tcp --dport "$port" -s "$subnet" -j ACCEPT
  done

  # Add allow-then-drop (order matters)
  iptables -I DOCKER-USER -p tcp --dport "$port" -s "$subnet" -j ACCEPT
  iptables -A DOCKER-USER -p tcp --dport "$port" -j DROP

  # Re-add RETURN at the end for other Docker traffic
  iptables -A DOCKER-USER -j RETURN
}

apply_docker_user_lock "${AWG_PORT}" "${VPN_SUBNET}"

# Install a persistent boot-time enforcer (systemd unit)
cat >/usr/local/sbin/lock-awg-ui.sh <<EOF
#!/bin/bash
set -e
PORT=${AWG_PORT}
SUBNET="${VPN_SUBNET}"
iptables -N DOCKER-USER 2>/dev/null || true

# Remove Docker's default RETURN rule
while iptables -C DOCKER-USER -j RETURN 2>/dev/null; do
  iptables -D DOCKER-USER -j RETURN
done

# Clean old rules for the port
while iptables -C DOCKER-USER -p tcp --dport "\$PORT" -j DROP 2>/dev/null; do
  iptables -D DOCKER-USER -p tcp --dport "\$PORT" -j DROP
done
while iptables -C DOCKER-USER -p tcp --dport "\$PORT" -s "\$SUBNET" -j ACCEPT 2>/dev/null; do
  iptables -D DOCKER-USER -p tcp --dport "\$PORT" -s "\$SUBNET" -j ACCEPT
done

# Allow VPN subnet, drop others
iptables -I DOCKER-USER -p tcp --dport "\$PORT" -s "\$SUBNET" -j ACCEPT
iptables -A DOCKER-USER -p tcp --dport "\$PORT" -j DROP

# Re-add RETURN at the end for other Docker traffic
iptables -A DOCKER-USER -j RETURN
EOF
chmod +x /usr/local/sbin/lock-awg-ui.sh

cat >/etc/systemd/system/lock-awg-ui.service <<'EOF'
[Unit]
Description=Enforce Docker Web UI firewall (DOCKER-USER)
After=docker.service ufw.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lock-awg-ui.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now lock-awg-ui.service

echo "[10/12] DOCKER-USER rules applied and persistence enabled."
echo "        You can verify with:  iptables -S DOCKER-USER"

# ========= 11) Summary =========
echo
echo "==================== SUMMARY ===================="
echo " User:                    $NEWUSER"
if [[ "${USER_ALREADY_EXISTED}" == "true" ]]; then
  echo " User password:           (unchanged; user already existed)"
else
  echo " User password:           ${USER_PASS}"
fi
echo " Imported root keys:      ${ROOT_KEYS_IMPORTED}"
echo " Root password:           ${ROOT_PASS}"
echo " SSH:                     port ${SSH_PORT}; root login = NO; passwords = NO; publickey only"
echo " UFW:                     SSH ${SSH_PORT}/tcp, WG ${WG_PORT}/udp"
echo "                          Web UI ${AWG_PORT}/tcp: allowed ONLY from ${VPN_SUBNET}, denied from Internet"
echo " awg-easy:                container ${CONTAINER_NAME}, Web UI on ${AWG_PORT}/tcp"
echo " WG_HOST (public IP):     ${WG_HOST}"
echo " Container IP:            ${CONTAINER_IP:-unknown}"
echo " Web UI login:            admin"
echo " Web UI password:         ${AWG_PASS}"
echo " PASSWORD_HASH (bcrypt):  ${PASSWORD_HASH}"
echo " DOCKER-USER persisted:   lock-awg-ui.service (enabled)"
echo "================================================="

# ========= 12) Reboot prompt =========
read -n 1 -s -r -p "Press any key to reboot the host..." _
echo
reboot