#!/bin/bash
set -e

WORKDIR="/home/build/openwrt"
FILES="$WORKDIR/files"
cp /scripts/make_openwrt_image.sh   "$WORKDIR/"
cp /scripts/openwrt.config          "$WORKDIR/.config"

PROFILE="${PROFILE:-512}"
INCLUDE_DOCKER="${INCLUDE_DOCKER:-no}"

SET_BRLAN_IPV4="${SET_BRLAN_IPV4:-no}"
BRLAN_IPV4="${BRLAN_IPV4:-192.168.2.1}"

ENABLE_MODEM_MANAGER="${ENABLE_MODEM_MANAGER:-no}"
MODEM_MANAGER_APN="${MODEM_MANAGER_APN:-}"
MODEM_MANAGER_PIN="${MODEM_MANAGER_PIN:-}"

if [ "${SET_BRLAN_IPV4}" = "yes" ]; then
cat > "${FILES}/etc/uci-defaults/11-set-lan-ip" <<'EOF'
#!/bin/sh
uci set network.lan.ipaddr='__BRLAN_IP__'
uci commit network
# 調整 DHCP 池
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit dhcp
exit 0
EOF
sed -i "s/__BRLAN_IP__/${BRLAN_IPV4}/" "${FILES}/etc/uci-defaults/11-set-lan-ip"
chmod +x "${FILES}/etc/uci-defaults/11-set-lan-ip"
fi

if [ "${ENABLE_MODEM_MANAGER}" = "yes" ]; then
  if [ -z "${MODEM_MANAGER_APN}" ]; then
    echo "ERROR: MODEM_MANAGER_APN is empty!"
    exit 1
  fi
cat > "${FILES}/etc/uci-defaults/12-modemmanager" <<'EOF'
#!/bin/sh
uci batch <<UCI
set network.cell=interface
set network.cell.proto='modemmanager'
set network.cell.apn='__APN__'
UCI
[ -n "__PIN__" ] && uci set network.cell.pin='__PIN__'
uci commit network
exit 0
EOF
  sed -i "s/__APN__/${MODEM_MANAGER_APN}/" "${FILES}/etc/uci-defaults/12-modemmanager"
  sed -i "s/__PIN__/${MODEM_MANAGER_PIN}/"  "${FILES}/etc/uci-defaults/12-modemmanager"
  chmod +x "${FILES}/etc/uci-defaults/12-modemmanager"
fi

PKG="curl luci-i18n-firewall-zh-tw luci-i18n-package-manager-zh-tw \
     luci-i18n-ttyd-zh-tw script-utils"

EXTRA="base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools \
grub2-bios-setup kmod-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls \
logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp \
ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd \
kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-dwmac-intel kmod-e1000e kmod-e1000 \
kmod-forcedeth kmod-fs-vfat kmod-igb kmod-igc kmod-ixgbe kmod-r8169 kmod-tg3 \
kmod-drm-i915 luci kmod-mtk-t7xx kmod-phy-aquantia kmod-sfp kmod-wwan \
kmod-usb-net-rndis kmod-usb-serial kmod-usb-serial-option kmod-usb3 \
luci-proto-mbim luci-proto-ncm comgt pciutils usbutils block-mount \
ethtool-full iperf3 luci-i18n-base-zh-tw kmod-usb-net-cdc-mbim umbim picocom \
kmod-scsi-core kmod-block2mtd fdisk lsblk speedtest-go kmod-tcp-bbr \
luci-i18n-uhttpd-zh-tw luci-i18n-sqm-zh-tw luci-i18n-cloudflared-zh-tw \
luci-i18n-acme-zh-tw luci-app-uhttpd luci-app-sqm luci-app-acme"

PKG="${PKG} ${EXTRA}"

[ "${INCLUDE_DOCKER}" = "yes" ] && PKG+=" luci-i18n-dockerman-zh-tw"
[ "${ENABLE_MODEM_MANAGER}" = "yes" ] && PKG+=" modemmanager luci-proto-modemmanager"

echo "[`date '+%F %T'`] Packages: ${PKG}"

make image PROFILE="generic" \
     PACKAGES="${PKG}" \
     FILES="${FILES}" \
     ROOTFS_PARTSIZE="${PROFILE}"


if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."