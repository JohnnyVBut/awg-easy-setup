#!/bin/bash
set -euo pipefail

# ========= Settings =========
SSH_PORT=9722
SSHD_CONFIG="/etc/ssh/sshd_config"
DEFAULT_USER="admino"
WG_PORT=54321                 # WireGuard UDP port (exposed)
AWG_PORT=8888                 # awg-easy Web UI port
VPN_SUBNET="10.8.0.0/24"      # Web UI allowed only from this subnet after bootstrap
CONTAINER_NAME="awg-easy"
IMAGE_REF="ghcr.io/johnnyvbut/awg-easy:latest"

# ========= Preconditions =========
if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root (or via sudo)."
  exit 1
fi
command -v apt >/dev/null || { echo "This script expects apt (Ubuntu/Debian)."; exit 1; }

# ========= 1) Update & upgrade =========
echo "[1/11] Updating packages..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt -y upgrade

# ========= 2) Install Docker (official repo), OpenSSH, UFW, tools =========
echo "[2/11] Installing Docker (official repo), OpenSSH, UFW, and tools..."
apt install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https
apt remove -y docker docker-engine docker.io containerd runc || true

install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
chmod a+r /etc/apt/keyrings/docker.gpg

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  UBUNTU_CODENAME="${VERSION_CODENAME:-$(lsb_release -cs)}"
else
  UBUNTU_CODENAME="$(lsb_release -cs)"
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt install -y openssh-server ufw python3 python3-pip git jq vim htop unzip zip apache2-utils dnsutils

systemctl enable --now docker
systemctl enable --now ssh

# ========= 3) Create sudo user (10s prompt) =========
echo "[3/11] Creating a sudo user (you have 10 seconds to type a name)..."
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
  usermod -aG sudo,docker "$NEWUSER"
  echo "User $NEWUSER created and added to groups: sudo,docker."
fi

HOME_DIR="$(eval echo "~$NEWUSER")"

# ========= 4) SSH keys for new user + import root's authorized_keys =========
echo "[4/11] Generating SSH keys and importing /root/.ssh/authorized_keys..."
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
echo "[5/11] Setting a random password for root (SSH login for root stays disabled)..."
ROOT_PASS="$(openssl rand -base64 24 | tr -d '\n')"
echo "root:${ROOT_PASS}" | chpasswd

# ========= 6) Harden SSH: public-key only, no passwords, no root, custom port =========
echo "[6/11] Hardening SSH (port ${SSH_PORT}, disable passwords, root login off)..."
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
echo "[6/11] Effective SSH options (sanity check):"
sshd -T | egrep 'port|passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|pubkeyauthentication|authenticationmethods|permitrootlogin' || true

systemctl restart ssh

# ========= 7) UFW: expose SSH & WG; do NOT open UI yet =========
echo "[7/11] Configuring UFW (allow SSH ${SSH_PORT}/tcp and WG ${WG_PORT}/udp)..."
ufw allow "${SSH_PORT}/tcp" || true
ufw allow "${WG_PORT}/udp" || true
if ! ufw status | grep -q "Status: active"; then
  echo "y" | ufw enable || true
fi
ufw reload || true

# ========= 8) Run awg-easy (publish UI) & TEMPORARILY open UI via UFW =========
echo "[8/11] Running awg-easy container (publishing UI ${AWG_PORT}/tcp)..."
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
echo "[8/11] Waiting for container to start..."
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

echo
echo ">>> TEMPORARY Web UI access is OPEN to the Internet."
echo "    Please open this URL NOW and create at least one VPN client:"
echo "    URL:  http://${WG_HOST}:${AWG_PORT}"
echo "    User: admin"
echo "    Pass: ${AWG_PASS}"
echo
read -r -p "When DONE creating a VPN client, press ENTER to lock the Web UI to VPN-only... " _

# ========= 9) LOCK Web UI to VPN-only: UFW + DOCKER-USER chain =========
echo "[9/11] Locking the Web UI to VPN-only (${VPN_SUBNET})..."

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
}

apply_docker_user_lock "${AWG_PORT}" "${VPN_SUBNET}"

# Install a persistent boot-time enforcer (systemd unit)
cat >/usr/local/sbin/lock-awg-ui.sh <<EOF
#!/bin/bash
set -e
PORT=${AWG_PORT}
SUBNET="${VPN_SUBNET}"
iptables -N DOCKER-USER 2>/dev/null || true
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

echo "[9/11] DOCKER-USER rules applied and persistence enabled."
echo "       You can verify with:  iptables -S DOCKER-USER"

# ========= 10) Summary =========
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

# ========= 11) Reboot prompt =========
read -n 1 -s -r -p "Press any key to reboot the host..." _
echo
reboot