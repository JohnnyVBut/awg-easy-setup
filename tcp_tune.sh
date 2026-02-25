#!/bin/bash
# tcp-tune.sh — автонастройка TCP буферов в зависимости от RAM

set -e

# ── цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

# ── root? ──────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && die "Нужен root"

# ── RAM в байтах ───────────────────────────────────────────────────────────
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_MB=$((RAM_KB / 1024))
RAM_GB=$(echo "scale=1; $RAM_MB / 1024" | bc)

info "Обнаружено RAM: ${RAM_MB} MB (${RAM_GB} GB)"

# ── расчёт буферов ─────────────────────────────────────────────────────────
# Логика: отдаём ~15% RAM под сетевые буферы, но с разумными потолками
# net.core.*   — глобальные (max на 1 сокет)
# net.ipv4.tcp_rmem/wmem — min / default / max на сокет

if   [[ $RAM_MB -lt 512 ]]; then
    TIER="tiny (<512MB)"
    CORE_RMAX=$((512  * 1024))        #  512 KB
    CORE_WMAX=$((512  * 1024))
    CORE_RDEF=$((64   * 1024))        #   64 KB
    CORE_WDEF=$((64   * 1024))
    TCP_RMIN=4096;  TCP_RDEF=$((32  * 1024)); TCP_RMAX=$((512  * 1024))
    TCP_WMIN=4096;  TCP_WDEF=$((16  * 1024)); TCP_WMAX=$((512  * 1024))
    BACKLOG=256; SOMAXCONN=512; TW_BUCKETS=8192

elif [[ $RAM_MB -lt 1024 ]]; then
    TIER="small (512MB–1GB)"
    CORE_RMAX=$((4    * 1024 * 1024)) #   4 MB
    CORE_WMAX=$((4    * 1024 * 1024))
    CORE_RDEF=$((128  * 1024))        # 128 KB
    CORE_WDEF=$((128  * 1024))
    TCP_RMIN=4096;  TCP_RDEF=$((65  * 1024)); TCP_RMAX=$((4 * 1024 * 1024))
    TCP_WMIN=4096;  TCP_WDEF=$((32  * 1024)); TCP_WMAX=$((4 * 1024 * 1024))
    BACKLOG=512; SOMAXCONN=1024; TW_BUCKETS=32768

elif [[ $RAM_MB -lt 2048 ]]; then
    TIER="medium (1–2GB)"
    CORE_RMAX=$((8    * 1024 * 1024)) #   8 MB
    CORE_WMAX=$((8    * 1024 * 1024))
    CORE_RDEF=$((256  * 1024))
    CORE_WDEF=$((256  * 1024))
    TCP_RMIN=4096;  TCP_RDEF=$((87  * 1024)); TCP_RMAX=$((8 * 1024 * 1024))
    TCP_WMIN=4096;  TCP_WDEF=$((65  * 1024)); TCP_WMAX=$((8 * 1024 * 1024))
    BACKLOG=1024; SOMAXCONN=2048; TW_BUCKETS=131072

elif [[ $RAM_MB -lt 8192 ]]; then
    TIER="large (2–8GB)"
    CORE_RMAX=$((16   * 1024 * 1024)) #  16 MB
    CORE_WMAX=$((16   * 1024 * 1024))
    CORE_RDEF=$((512  * 1024))
    CORE_WDEF=$((512  * 1024))
    TCP_RMIN=4096;  TCP_RDEF=$((87  * 1024)); TCP_RMAX=$((16 * 1024 * 1024))
    TCP_WMIN=4096;  TCP_WDEF=$((65  * 1024)); TCP_WMAX=$((16 * 1024 * 1024))
    BACKLOG=4096; SOMAXCONN=8192; TW_BUCKETS=262144

else
    TIER="xlarge (>8GB)"
    CORE_RMAX=$((32   * 1024 * 1024)) #  32 MB
    CORE_WMAX=$((32   * 1024 * 1024))
    CORE_RDEF=$((1024 * 1024))        #   1 MB
    CORE_WDEF=$((1024 * 1024))
    TCP_RMIN=4096;  TCP_RDEF=$((87  * 1024)); TCP_RMAX=$((32 * 1024 * 1024))
    TCP_WMIN=4096;  TCP_WDEF=$((65  * 1024)); TCP_WMAX=$((32 * 1024 * 1024))
    BACKLOG=8192; SOMAXCONN=65535; TW_BUCKETS=1440000
fi

info "Tier: ${BOLD}${TIER}${NC}"

# ── BBR ────────────────────────────────────────────────────────────────────
BBR_OK=0
if modprobe tcp_bbr 2>/dev/null; then
    BBR_OK=1
    ok "tcp_bbr модуль загружен"
else
    warn "tcp_bbr недоступен (старое ядро?), остаётся cubic"
fi

# ── применяем sysctl ───────────────────────────────────────────────────────
apply() {
    local key=$1 val=$2
    sysctl -qw "${key}=${val}" && ok "${key} = ${val}" || warn "Не удалось: ${key}"
}

echo -e "\n${BOLD}── Буферы (глобальные) ──────────────────────────────${NC}"
apply net.core.rmem_max        $CORE_RMAX
apply net.core.wmem_max        $CORE_WMAX
apply net.core.rmem_default    $CORE_RDEF
apply net.core.wmem_default    $CORE_WDEF
apply net.core.netdev_max_backlog 5000
apply net.core.somaxconn       $SOMAXCONN

echo -e "\n${BOLD}── TCP буферы на сокет ──────────────────────────────${NC}"
apply net.ipv4.tcp_rmem        "${TCP_RMIN} ${TCP_RDEF} ${TCP_RMAX}"
apply net.ipv4.tcp_wmem        "${TCP_WMIN} ${TCP_WDEF} ${TCP_WMAX}"

echo -e "\n${BOLD}── Congestion control ───────────────────────────────${NC}"
if [[ $BBR_OK -eq 1 ]]; then
    apply net.core.default_qdisc          fq
    apply net.ipv4.tcp_congestion_control bbr
else
    apply net.core.default_qdisc          fq
    apply net.ipv4.tcp_congestion_control cubic
fi

echo -e "\n${BOLD}── TIME_WAIT и очереди ──────────────────────────────${NC}"
apply net.ipv4.tcp_max_tw_buckets     $TW_BUCKETS
apply net.ipv4.tcp_max_syn_backlog    $BACKLOG
apply net.ipv4.tcp_tw_reuse           1
apply net.ipv4.tcp_fin_timeout        15

echo -e "\n${BOLD}── Прочие TCP оптимизации ───────────────────────────${NC}"
apply net.ipv4.tcp_fastopen           3
apply net.ipv4.tcp_mtu_probing        1
apply net.ipv4.tcp_slow_start_after_idle 0
apply net.ipv4.tcp_sack               1
apply net.ipv4.tcp_dsack              1
apply net.ipv4.tcp_ecn                1
apply net.ipv4.tcp_keepalive_time     60
apply net.ipv4.tcp_keepalive_intvl    10
apply net.ipv4.tcp_keepalive_probes   6

# ── fq на все интерфейсы ───────────────────────────────────────────────────
echo -e "\n${BOLD}── qdisc на интерфейсах ─────────────────────────────${NC}"
for iface in $(ls /sys/class/net/ | grep -v lo); do
    if tc qdisc replace dev "$iface" root fq 2>/dev/null; then
        ok "fq → $iface"
    else
        warn "Не удалось заменить qdisc на $iface"
    fi
done

# ── сохранить в sysctl.d ───────────────────────────────────────────────────
SYSCTL_FILE="/etc/sysctl.d/99-tcp-tuning.conf"
echo -e "\n${BOLD}── Сохранение в ${SYSCTL_FILE} ───────────────────────${NC}"

cat > "$SYSCTL_FILE" << EOF
# Auto-generated by tcp-tune.sh | RAM tier: ${TIER}
# $(date)

net.core.rmem_max             = $CORE_RMAX
net.core.wmem_max             = $CORE_WMAX
net.core.rmem_default         = $CORE_RDEF
net.core.wmem_default         = $CORE_WDEF
net.core.netdev_max_backlog   = 5000
net.core.somaxconn            = $SOMAXCONN
net.core.default_qdisc        = fq

net.ipv4.tcp_rmem             = $TCP_RMIN $TCP_RDEF $TCP_RMAX
net.ipv4.tcp_wmem             = $TCP_WMIN $TCP_WDEF $TCP_WMAX
net.ipv4.tcp_congestion_control = $([ $BBR_OK -eq 1 ] && echo bbr || echo cubic)

net.ipv4.tcp_max_tw_buckets   = $TW_BUCKETS
net.ipv4.tcp_max_syn_backlog  = $BACKLOG
net.ipv4.tcp_tw_reuse         = 1
net.ipv4.tcp_fin_timeout      = 15
net.ipv4.tcp_fastopen         = 3
net.ipv4.tcp_mtu_probing      = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_sack             = 1
net.ipv4.tcp_dsack            = 1
net.ipv4.tcp_ecn              = 1
net.ipv4.tcp_keepalive_time   = 60
net.ipv4.tcp_keepalive_intvl  = 10
net.ipv4.tcp_keepalive_probes = 6
EOF

ok "Сохранено → ${SYSCTL_FILE}"

# ── итог ───────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}══ Готово ══════════════════════════════════════════${NC}"
echo -e "  RAM:    ${RAM_MB} MB  |  Tier: ${TIER}"
echo -e "  rmem:   $(( CORE_RMAX / 1024 / 1024 )) MB max  |  wmem: $(( CORE_WMAX / 1024 / 1024 )) MB max"
echo -e "  BBR:    $([ $BBR_OK -eq 1 ] && echo -e "${GREEN}enabled${NC}" || echo -e "${YELLOW}cubic fallback${NC}")"
echo -e "  Config: ${SYSCTL_FILE}"