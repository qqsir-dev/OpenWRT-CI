#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build context (来自 WRT-CORE.yml env / inputs)
# ============================================================
WRT_CONFIG_BUILD="${WRT_CONFIG_BUILD:-${WRT_CONFIG:-}}"
WRT_IP_BUILD="${WRT_IP_BUILD:-${WRT_IP:-192.168.50.1}}"

# 可选：限制外网访问来源（为空=不限制）
WAN_MGMT_ALLOW_BUILD="${WAN_MGMT_ALLOW_BUILD:-${WAN_MGMT_ALLOW:-}}"

# ============================================================
# PPPoE credentials (来自 GitHub Secrets 注入 env)
#   PPPOE_X86_USER / PPPOE_X86_PASS / PPPOE_R68_USER / PPPOE_R68_PASS
# ============================================================
X86_PPPOE_USER_BUILD="${X86_PPPOE_USER_BUILD:-${PPPOE_X86_USER:-}}"
X86_PPPOE_PASS_BUILD="${X86_PPPOE_PASS_BUILD:-${PPPOE_X86_PASS:-}}"
R68_PPPOE_USER_BUILD="${R68_PPPOE_USER_BUILD:-${PPPOE_R68_USER:-}}"
R68_PPPOE_PASS_BUILD="${R68_PPPOE_PASS_BUILD:-${PPPOE_R68_PASS:-}}"

if [ -z "${WRT_CONFIG_BUILD:-}" ]; then
  echo "[write_uci_defaults] ERROR: WRT_CONFIG is empty"
  exit 1
fi

# ---- Shell-safe single-quote embed (handles special chars in passwords) ----
sh_quote() {
  local s=${1-}
  s=${s//\'/\'\"\'\"\'}
  printf "'%s'" "$s"
}

Q_WRT_CONFIG="$(sh_quote "$WRT_CONFIG_BUILD")"
Q_WRT_IP="$(sh_quote "$WRT_IP_BUILD")"
Q_WAN_MGMT_ALLOW="$(sh_quote "$WAN_MGMT_ALLOW_BUILD")"

Q_X86_USER="$(sh_quote "$X86_PPPOE_USER_BUILD")"
Q_X86_PASS="$(sh_quote "$X86_PPPOE_PASS_BUILD")"
Q_R68_USER="$(sh_quote "$R68_PPPOE_USER_BUILD")"
Q_R68_PASS="$(sh_quote "$R68_PPPOE_PASS_BUILD")"

# 998：尽量最后执行，避免被 991 之类覆盖；999 负责统一 restart
TARGET_FILE="./package/base-files/files/etc/uci-defaults/998_custom-net.sh"
mkdir -p "$(dirname "$TARGET_FILE")"

cat > "$TARGET_FILE" <<EOF
#!/bin/sh
# /etc/uci-defaults/998_custom-net.sh
# One-time init script: runs once at first boot.

set -e

TAG="[998_custom-net]"
log() { echo "\$TAG \$*"; }

WRT_CONFIG=$Q_WRT_CONFIG
WRT_IP=$Q_WRT_IP
WAN_MGMT_ALLOW=$Q_WAN_MGMT_ALLOW

X86_PPPOE_USER=$Q_X86_USER
X86_PPPOE_PASS=$Q_X86_PASS
R68_PPPOE_USER=$Q_R68_USER
R68_PPPOE_PASS=$Q_R68_PASS

# 保险丝：某些 key 不存在时不要炸（uci-defaults 最怕中途退出）
uciq() { uci -q "\$@" || true; }

ensure_list() {
  local key="\$1" val="\$2"
  uciq del_list "\$key=\$val"
  uciq add_list "\$key=\$val"
}

ensure_dhcp_host() {
  local sec="\$1" name="\$2" mac="\$3" ip="\$4"
  uciq set "dhcp.\$sec=host"
  uciq set "dhcp.\$sec.name=\$name"
  uciq set "dhcp.\$sec.mac=\$mac"
  uciq set "dhcp.\$sec.ip=\$ip"
  uciq set "dhcp.\$sec.leasetime=infinite"
}

# fw4 兼容：UCI 的 redirect 仍然有效
ensure_redirect() {
  local sec="\$1" src_dport="\$2" dest_ip="\$3" dest_port="\$4" proto="\$5"

  uciq set "firewall.\$sec=redirect"
  uciq set "firewall.\$sec.name=\$sec"
  uciq set "firewall.\$sec.target=DNAT"
  uciq set "firewall.\$sec.src=wan"
  uciq set "firewall.\$sec.dest=lan"
  uciq set "firewall.\$sec.proto=\$proto"
  uciq set "firewall.\$sec.src_dport=\$src_dport"
  uciq set "firewall.\$sec.dest_ip=\$dest_ip"
  uciq set "firewall.\$sec.dest_port=\$dest_port"

  # 默认不限制来源
  # 如 WAN_MGMT_ALLOW 非空则只允许该IP/CIDR访问
  if [ -n "\$WAN_MGMT_ALLOW" ]; then
    uciq set "firewall.\$sec.src_ip=\$WAN_MGMT_ALLOW"
  else
    uciq delete "firewall.\$sec.src_ip"
  fi
}

log "Start. WRT_CONFIG='\$WRT_CONFIG' WRT_IP='\$WRT_IP'"

# ============================================================
# TTYD: listen on all interfaces (unspecified)
# ============================================================
# 删除 interface 选项 = unspecified
uciq delete ttyd.@ttyd[0].interface
uciq commit ttyd

# ============================================================
# X86 (matrix= X86)
# ============================================================
if echo "\$WRT_CONFIG" | grep -Eiq "X86|64|86"; then
  log "Match: X86"

  # PPPoE + WAN 口
  # ⚠️ x86 网卡名可能不是 eth1，若拨号失败先在设备上 ip link 看看再改
  uciq set "network.wan.device=eth1"
  if [ -n "\$X86_PPPOE_USER" ] && [ -n "\$X86_PPPOE_PASS" ]; then
    uciq set "network.wan.proto=pppoe"
    uciq set "network.wan.username=\$X86_PPPOE_USER"
    uciq set "network.wan.password=\$X86_PPPOE_PASS"
    log "X86 PPPoE set."
  else
    log "X86 PPPoE empty; skip."
  fi
  uciq commit network

  # DHCP / RA（不开放 IPv6，这里不做 relay，不做奇怪的 ndp/ra relay）
  ensure_list dhcp.lan.dhcp_option "6,119.29.29.29,223.5.5.5,208.67.222.222,1.1.1.1,114.114.114.114,180.76.76.76"
  uciq set "dhcp.lan.ra=server"
  uciq set "dhcp.lan.dhcpv6=server"
  uciq set "dhcp.lan.ndp=disabled"
  uciq set "dhcp.lan.ra_management=1"
  uciq set "dhcp.lan.ra_default=1"
  uciq set "dhcp.lan.ra_flags=none"

  # 静态租约
  ensure_dhcp_host home_srv "HOME-SRV" "90:2e:16:bd:0b:cc" "192.168.50.8"
  ensure_dhcp_host ap       "AP"       "60:cf:84:28:8f:80" "192.168.50.6"
  uciq commit dhcp

  # =========================
  # Firewall redirects (DNAT)
  # =========================

  # KMS
  ensure_redirect kms          1688  "\$WRT_IP"        1688  "tcp udp"

  # RDP
  ensure_redirect rdp          3389  "192.168.50.8"   3389  "tcp"

  # DayZ
  ensure_redirect dayz_2302    2302  "192.168.50.8"   2302  "tcp udp"
  ensure_redirect dayz_27016   27016 "192.168.50.8"   27016 "udp"
  ensure_redirect dayz_2308    2308  "192.168.50.8"   2308  "tcp udp"

  # Router 
  ensure_redirect router_http  8098  "\$WRT_IP"        80    "tcp"
  ensure_redirect router_https 8043  "\$WRT_IP"        443   "tcp"

  # OpenClash Dashboard 
  ensure_redirect openclash_9090 9090  "\$WRT_IP"      9090  "tcp"

  # Router local netdata 
  ensure_redirect lede_netdata 19999 "\$WRT_IP"        19999 "tcp"

  # TTYD 
  ensure_redirect ttyd_7681    7681  "\$WRT_IP"        7681  "tcp"

  # ESXi Web 
  ensure_redirect esxi_http    8096  "192.168.50.11"  80    "tcp"

  uciq commit firewall

  # LuCI 语言
  uciq set "luci.main.lang=en"
  uciq commit luci
fi

# ============================================================
# R68S (matrix= R68S)
# ============================================================
if echo "\$WRT_CONFIG" | grep -Eiq "R68"; then
  log "Match: R68"

  uciq set "network.wan.device=eth3"
  if [ -n "\$R68_PPPOE_USER" ] && [ -n "\$R68_PPPOE_PASS" ]; then
    uciq set "network.wan.proto=pppoe"
    uciq set "network.wan.username=\$R68_PPPOE_USER"
    uciq set "network.wan.password=\$R68_PPPOE_PASS"
    log "R68 PPPoE set."
  else
    log "R68 PPPoE empty; skip."
  fi

  # Lan ports
  uciq set "network.@device[0].ports=eth0 eth1 eth2"
  uciq commit network

  # DHCP / RA
  uciq set "dhcp.lan.start=150"
  uciq set "dhcp.lan.limit=100"
  ensure_list dhcp.lan.dhcp_option "6,119.29.29.29,223.5.5.5,208.67.222.222,1.1.1.1,114.114.114.114,180.76.76.76"
  uciq set "dhcp.lan.ra=server"
  uciq set "dhcp.lan.dhcpv6=server"
  uciq set "dhcp.lan.ndp=disabled"
  uciq set "dhcp.lan.ra_management=1"
  uciq set "dhcp.lan.ra_default=1"
  uciq set "dhcp.lan.ra_flags=none"
  uciq commit dhcp

  # Firewall redirects (DNAT)
  ensure_redirect router_http     8098 "\$WRT_IP" 80   "tcp"
  ensure_redirect router_https    8043 "\$WRT_IP" 443  "tcp"
  ensure_redirect openclash_9090  9090 "\$WRT_IP" 9090 "tcp"
  ensure_redirect ttyd_7681       7681 "\$WRT_IP" 7681 "tcp"
  ensure_redirect lede_netdata    19999 "\$WRT_IP" 19999 "tcp"
  uciq commit firewall

  # uciq set "luci.main.lang=en"
  # uciq commit luci
fi

# ============================================================
# ROCKCHIP (matrix= ROCKCHIP)
# ============================================================
if echo "\$WRT_CONFIG" | grep -Eiq "ROCK"; then
  log "Match: ROCK"

  uciq set "network.lan.delegate=0"
  uciq commit network

  uciq set "dhcp.lan.start=150"
  uciq set "dhcp.lan.limit=100"
  ensure_list dhcp.lan.dhcp_option "6,119.29.29.29,223.5.5.5,208.67.222.222,1.1.1.1,114.114.114.114,180.76.76.76"
  uciq set "dhcp.lan.ra=server"
  uciq set "dhcp.lan.dhcpv6=server"
  uciq set "dhcp.lan.ndp=disabled"
  uciq set "dhcp.lan.ra_management=1"
  uciq set "dhcp.lan.ra_default=1"
  uciq set "dhcp.lan.ra_flags=none"
  uciq commit dhcp

  # Firewall redirects (DNAT)
  ensure_redirect router_http     8098 "\$WRT_IP" 80   "tcp"
  ensure_redirect router_https    8043 "\$WRT_IP" 443  "tcp"
  ensure_redirect openclash_9090  9090 "\$WRT_IP" 9090 "tcp"
  ensure_redirect ttyd_7681       7681 "\$WRT_IP" 7681 "tcp"
  ensure_redirect lede_netdata    19999 "\$WRT_IP" 19999 "tcp"
  uciq commit firewall

  # uciq set "luci.main.lang=en"
  # uciq commit luci
fi

# ddns-go: copy private config into ddns-go dir (avoid build-time file conflict)
if [ -f /etc/ddns-go-config.yaml ]; then
  mkdir -p /etc/ddns-go
  cp -f /etc/ddns-go-config.yaml /etc/ddns-go/ddns-go-config.yaml || true
  echo "✅ [write_uci_defaults] ddns-go-config.yaml coied to /etc/ddns-go"
fi

# ddns-go: enable only (restart in 999 after network is ready)
if [ -x /etc/init.d/ddns-go ]; then
  uciq set ddns-go.config.enabled='1'
  uciq commit ddns-go
  /etc/init.d/ddns-go enable || true
fi

log "Done."
exit 0
EOF

chmod 0755 "$TARGET_FILE"
echo "[write_uci_defaults] wrote $TARGET_FILE (WRT_CONFIG=$WRT_CONFIG_BUILD)"

# ------------------------------------------------------------
# Patch or create 999_auto-restart.sh to restart services
# (idempotent, stable on first boot) -- awk-based, sed-safe
# ------------------------------------------------------------
UCI_DEFAULTS_DIR="./package/base-files/files/etc/uci-defaults"
AUTO_999="${UCI_DEFAULTS_DIR}/999_auto-restart.sh"
mkdir -p "$UCI_DEFAULTS_DIR"

PATCH_MARK_BEGIN="# --- added by write_uci_defaults: stabilize first boot ---"
PATCH_MARK_END="# --- end added by write_uci_defaults ---"

PATCH_PAYLOAD=$(cat <<'EOS'
# --- added by write_uci_defaults: stabilize first boot ---
# Ensure core services reload after first-boot network is ready

if [ -x /etc/init.d/network ]; then
  /etc/init.d/network restart || true
fi
if [ -x /etc/init.d/odhcpd ]; then
  /etc/init.d/odhcpd restart || true
fi
if [ -x /etc/init.d/rpcd ]; then
  /etc/init.d/rpcd restart || true
fi

# Restart dnsmasq so DHCP/DNS options take effect
if [ -x /etc/init.d/dnsmasq ]; then
  /etc/init.d/dnsmasq restart || true
fi

# Restart firewall after network is ready (fw4 needs this for DNAT)
if [ -x /etc/init.d/firewall ]; then
  /etc/init.d/firewall restart || true
fi

# Restart ddns-go after network/DNS is ready
if [ -x /etc/init.d/ddns-go ]; then
  /etc/init.d/ddns-go restart || true
fi
# --- end added by write_uci_defaults ---
EOS
)

create_999() {
  cat > "$AUTO_999" <<'EOF'
#!/bin/sh

# Created by write_uci_defaults.sh
# Runs once at first boot (uci-defaults).

EOF

  printf "%s\n\n" "$PATCH_PAYLOAD" >> "$AUTO_999"

  cat >> "$AUTO_999" <<'EOF'
exit 0
EOF

  chmod 0755 "$AUTO_999"
  echo "✅ [write_uci_defaults] created $AUTO_999"
}

patch_999_awk() {
  chmod 0755 "$AUTO_999" || true

  # 幂等：已存在则跳过
  if grep -qF "$PATCH_MARK_BEGIN" "$AUTO_999" 2>/dev/null; then
    echo "✅ [write_uci_defaults] patch already present in $AUTO_999"
    return 0
  fi

  # 如果没有 exit 0，就追加一个，确保插入点存在
  if ! grep -qE '^exit 0$' "$AUTO_999"; then
    printf "\nexit 0\n" >> "$AUTO_999"
  fi

  local tmp
  tmp="$(mktemp)"

  # awk：遇到 exit 0 前插入 payload（一次）
  awk -v payload="$PATCH_PAYLOAD" '
    $0=="exit 0" && !done {
      print payload
      print ""
      done=1
    }
    { print }
  ' "$AUTO_999" > "$tmp"

  mv "$tmp" "$AUTO_999"
  chmod 0755 "$AUTO_999" || true
  echo "✅ [write_uci_defaults] patched $AUTO_999"
}

if [ -f "$AUTO_999" ]; then
  patch_999_awk
else
  create_999
fi

