#!/bin/sh
# 99-custom.sh ── 首次開機自動設定

###############################################################################
# 0. 動態收集網卡 (eth*/en*)
###############################################################################
ports=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        ports="$ports $iface_name"
    fi
done
ports=$(echo "$ports" | awk '{$1=$1};1')   # 去掉前導空白

###############################################################################
# 1. br-lan 介面設定
###############################################################################
uci -q delete network.br_lan                   # 清除舊的 device 定義（若存在）
uci set network.br_lan='device'
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci set network.br_lan.ports="$ports"          # ← 自動加所有網卡

uci set network.lan.device='br-lan'            # LAN 介面掛到這條 bridge
uci set network.lan.proto='static'
uci set network.lan.ipaddr='__BRLAN_IP__'
uci set network.lan.netmask='255.255.255.0'

###############################################################################
# 2. DHCP 設定
###############################################################################
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

###############################################################################
# 3. ModemManager (若啟用)
###############################################################################
if [ "__ENABLE_MM__" = "yes" ]; then
    uci batch <<UCI
set network.cell=interface
set network.cell.proto='modemmanager'
set network.cell.apn='__APN__'
set network.cell.loglevel='ERR'
set network.cell.iptype = 'ipv4v6'
UCI
    [ -n "__PIN__" ] && uci set network.cell.pincode='__PIN__'
fi

###############################################################################
# 4. 基本防火牆區 (Docker 用) ── 若你無 Docker 可刪掉此段
###############################################################################
uci add firewall zone
uci set firewall.@zone[-1].name='docker'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].device='docker0'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='docker'
uci set firewall.@forwarding[-1].dest='lan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='docker'
uci set firewall.@forwarding[-1].dest='wan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='docker'

###############################################################################
# 5. 改版號 (openwrt_release)
###############################################################################
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by MattFlow"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

###############################################################################
# 6. 寫入設定並結束
###############################################################################
uci commit network
uci commit dhcp
uci commit firewall
exit 0
