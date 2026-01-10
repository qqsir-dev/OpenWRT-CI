#!/usr/bin/env bash
set -euo pipefail

# === build context from workflow env (WRT-CORE.yml env 已经定义) ===
WRT_CONFIG_BUILD="${WRT_CONFIG_BUILD:-${WRT_CONFIG:-}}"
WRT_IP_BUILD="${WRT_IP_BUILD:-${WRT_IP:-192.168.50.1}}"
WAN_MGMT_ALLOW_BUILD="${WAN_MGMT_ALLOW_BUILD:-${WAN_MGMT_ALLOW:-}}"

# === PPPoE from GitHub Secrets injected env ===
# Secrets 名字：PPPOE_X86_USER / PPPOE_X86_PASS / PPPOE_R68_USER / PPPOE_R68_PASS
X86_PPPOE_USER_BUILD="${X86_PPPOE_USER_BUILD:-${PPPOE_X86_USER:-}}"
X86_PPPOE_PASS_BUILD="${X86_PPPOE_PASS_BUILD:-${PPPOE_X86_PASS:-}}"
R68_PPPOE_USER_BUILD="${R68_PPPOE_USER_BUILD:-${PPPOE_R68_USER:-}}"
R68_PPPOE_PASS_BUILD="${R68_PPPOE_PASS_BUILD:-${PPPOE_R68_PASS:-}}"

if [ -z "${WRT_CONFIG_BUILD:-}" ]; then
  echo "[write_uci_defaults] ERROR: WRT_CONFIG is empty"
  exit 1
fi

# --- safe single-quote embed for generated uci-defaults script ---
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

# ✅ 你要求：用 998 更保险
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

# ✅ 保险丝：即使某个 uci key 不存在也不要炸
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

  # 管理类端口：默认锁死；如 WAN_MGMT_ALLOW 非空则只允许该IP/CIDR访问
  case "\$sec" in
    router_http|router_https|ttyd|openclash|lede_netdata|netdata|esxi_http)
      if [ -n "\$WAN_MGMT_ALLOW" ]; then
        uciq set "firewall.\$sec.src_ip=\$WAN_MGMT_ALLOW"
      else
        uciq set "firewall.\$sec.src_ip=127.0.0.1/32"
      fi
    ;;
  esac
}

log "Start. WRT_CONFIG='\$WRT_CONFIG' WRT_IP='\$WRT_IP'"

# ------------------------------------------------------------
# X86 (matrix= X86) — 兼容旧判断 64/86
# ------------------------------------------------------------
if echo "\$WRT_CONFIG" | grep -Eiq "X86|64|86"; then
  log "Match: X86"

  # ⚠️ x86 网卡名可能不是 eth1，如需再改
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

  # DHCP / RA (按你原风格：server-only)
  ensure_list dhcp.lan.dhcp_option "6,119.29.29.29,223.5.5.5,208.67.222.222,1.1.1.1,114.114.114.114,180.76.76.76"
  uciq set "dhcp.lan.ra=server"
  uciq set "dhcp.lan.dhcpv6=server"
  uciq set "dhcp.lan.ndp=disabled"
  uciq set "dhcp.lan.ra_management=1"
  uciq set "dhcp.lan.ra_default=1"
  uciq set "dhcp.lan.ra_flags=none"

  ensure_dhcp_host home_srv "HOME-SRV" "90:2e:16:bd:0b:cc" "192.168.50.8"
  ensure_dhcp_host ap       "AP"       "60:cf:84:28:8f:80" "192.168.50.6"
  uciq commit dhcp

  # 常用端口（你可继续扩展成完整端口列表）
  ensure_redirect router_http  8098 "\$WRT_IP" 80   "tcp udp"
  ensure_redirect router_https 8043 "\$WRT_IP" 443  "tcp udp"
  ensure_redirect openclash    9090 "\$WRT_IP" 9090 "tcp udp"
  ensure_redirect ttyd         7681 "\$WRT_IP" 7681 "tcp"
  uciq commit firewall

  uciq set "luci.main.lang=en"
  uciq commit luci
fi

# ------------------------------------------------------------
# R68S (matrix= R68S) — 匹配 R68 即可命中
# ------------------------------------------------------------
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

  uciq set "network.@device[0].ports=eth0 eth1 eth2"
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

  ensure_redirect router_http  8098 "\$WRT_IP" 80   "tcp udp"
  ensure_redirect router_https 8043 "\$WRT_IP" 443  "tcp udp"
  ensure_redirect openclash    9090 "\$WRT_IP" 9090 "tcp udp"
  ensure_redirect ttyd         7681 "\$WRT_IP" 7681 "tcp"
  uciq commit firewall

  uciq set "luci.main.lang=en"
  uciq commit luci
fi

# ------------------------------------------------------------
# ROCKCHIP (matrix= ROCKCHIP) — 匹配 ROCK 即可命中
# ------------------------------------------------------------
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

  ensure_redirect router_http 8098 "\$WRT_IP" 80 "tcp udp"
  uciq commit firewall

  uciq set "luci.main.lang=en"
  uciq commit luci
fi

# ✅ 额外重启防火墙（999 不会重启 firewall）
if [ -x /etc/init.d/firewall ]; then
  /etc/init.d/firewall restart || true
fi

log "Done."
exit 0
EOF

chmod 0755 "$TARGET_FILE"
echo "[write_uci_defaults] wrote $TARGET_FILE (WRT_CONFIG=$WRT_CONFIG_BUILD)"
