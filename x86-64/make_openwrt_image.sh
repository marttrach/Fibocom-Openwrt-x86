#!/bin/bash
set -e

make info 

PROFILE="${PROFILE:-512}"
INCLUDE_DOCKER="${INCLUDE_DOCKER:-no}"

SET_BRLAN_IPV4="${SET_BRLAN_IPV4:-yes}"
BRLAN_IPV4="${BRLAN_IPV4:-192.168.2.1}"

ENABLE_MODEM_MANAGER="${ENABLE_MODEM_MANAGER:-no}"
MODEM_MANAGER_APN="${MODEM_MANAGER_APN:-internet}"
MODEM_MANAGER_PIN="${MODEM_MANAGER_PIN:-}"

if [[ "$(pwd)" != "/builder" ]]; then
  echo This action assumes that the imagebuilder docker image default folder is '/builder' but found:
  pwd
  exit -1
fi

UCI_SCRIPT="$FILES/etc/uci-defaults/99-custom.sh"

[ "$SET_BRLAN_IPV4" = "yes" ] && \
    sed -i "s/__BRLAN_IP__/${BRLAN_IPV4}/" "$UCI_SCRIPT"

if [ "$ENABLE_MODEM_MANAGER" = "yes" ]; then
    sed -i "s/__ENABLE_MM__/yes/" "$UCI_SCRIPT"
    sed -i "s/__APN__/${MODEM_MANAGER_APN}/" "$UCI_SCRIPT"
    sed -i "s/__PIN__/${MODEM_MANAGER_PIN}/" "$UCI_SCRIPT"
else
    sed -i "s/__ENABLE_MM__/no/"  "$UCI_SCRIPT"
fi

chmod +x "$UCI_SCRIPT"

PKG="curl luci-i18n-firewall-zh-tw luci-i18n-package-manager-zh-tw \
     luci-i18n-ttyd-zh-tw script-utils"

EXTRA1="base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools \
grub2-bios-setup kmod-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls \
logd mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils \
procd-ujail uci uclient-fetch urandom-seed urngd \
kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-dwmac-intel kmod-e1000e kmod-e1000 \
kmod-forcedeth kmod-fs-vfat kmod-igb kmod-igc kmod-ixgbe kmod-r8169 kmod-tg3 \
luci kmod-mtk-t7xx kmod-phy-aquantia kmod-sfp kmod-wwan \
kmod-usb-net-rndis kmod-usb-serial kmod-usb-serial-option kmod-usb3 \
luci-proto-mbim luci-proto-ncm comgt pciutils usbutils block-mount \
ethtool-full iperf3 luci-i18n-base-zh-tw kmod-usb-net-cdc-mbim umbim picocom \
kmod-scsi-core kmod-block2mtd fdisk lsblk speedtest-go kmod-tcp-bbr \
luci-i18n-uhttpd-zh-tw luci-i18n-sqm-zh-tw luci-i18n-cloudflared-zh-tw \
luci-i18n-acme-zh-tw"

EXTRA2="luci-app-uhttpd luci-app-sqm luci-app-acme kmod-usb-serial-wwan"

PKG="${PKG} ${EXTRA1} ${EXTRA2}"

[ "${INCLUDE_DOCKER}" = "yes" ] && PKG+=" luci-i18n-dockerman-zh-tw"
[ "${ENABLE_MODEM_MANAGER}" = "yes" ] && PKG+=" modemmanager luci-proto-modemmanager"

[ "${INCLUDE_DOCKER}" = "yes" ] && PKG+=" luci-i18n-dockerman-zh-tw"
[ "${ENABLE_MODEM_MANAGER}" = "yes" ] && PKG+=" modemmanager luci-proto-modemmanager"

echo "[`date '+%F %T'`] Packages: ${PKG}"

sed -f config.sed -i .config

make image PROFILE="generic" PACKAGES="$PKG" FILES="/builder/files" ROOTFS_PARTSIZE="$PROFILE_MB"

echo "[`date '+%F %T'`] Build completed successfully."

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."