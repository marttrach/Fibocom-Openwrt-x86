#!/bin/bash
set -e 
PROFILE="${PROFILE:-512}"
INCLUDE_DOCKER="${INCLUDE_DOCKER:-no}"
SET_BRLAN_IPV4="${SET_BRLAN_IPV4:-no}"
BRLAN_IPV4="${BRLAN_IPV4:-192.168.2.1}"
ENABLE_MODEM_MANAGER="${ENABLE_MODEM_MANAGER:-no}"
MODEM_MANAGER_APN="${MODEM_MANAGER_APN:-internet}"
MODEM_MANAGER_PIN="${MODEM_MANAGER_PIN:-}"

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "Image Size: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create modem_manager-settings"
mkdir -p  /home/build/openwrt/files/etc/config

if [ "$SET_BRLAN_IPV4" = "yes" ]; then
  mkdir -p /home/build/openwrt/files/etc/uci-defaults
  cat << EOF > /home/build/openwrt/files/etc/uci-defaults/11-set-lan-ip
#!/bin/sh
uci -q set network.lan.ipaddr='${BRLAN_IPV4}'
uci -q commit network

# 調整 DHCP 租用池至同網段
uci -q set dhcp.lan.start='100'
uci -q set dhcp.lan.limit='150'
uci -q set dhcp.lan.leasetime='12h'
uci -q commit dhcp
exit 0
EOF
  chmod +x /home/build/openwrt/files/etc/uci-defaults/11-set-lan-ip
fi

if [ "$ENABLE_MODEM_MANAGER" = "yes" ]; then
  mkdir -p /home/build/openwrt/files/etc/uci-defaults
  cat << EOF > /home/build/openwrt/files/etc/uci-defaults/12-modemmanager
#!/bin/sh
uci -q batch << UCI_EOF
  set network.cell=interface
  set network.cell.proto='modemmanager'
  set network.cell.apn='${MODEM_MANAGER_APN}'
UCI_EOF
[ -n "${MODEM_MANAGER_PIN}" ] && uci set network.cell.pin="${MODEM_MANAGER_PIN}"
uci commit network
exit 0
EOF
  chmod +x /home/build/openwrt/files/etc/uci-defaults/12-modemmanager
fi

PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-tw"
#24.10
PACKAGES="$PACKAGES tluci-i18n-package-manager-zh-w"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-tw"
PACKAGES="$PACKAGES script-utils"

ADDITIONAL_PACKAGES="\
base-files ca-bundle dnsmasq dropbear e2fsprogs firewall4 fstools grub2-bios-setup \
kmod-button-hotplug kmod-nft-offload libc libgcc libustream-mbedtls logd mkf2fs mtd \
netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-modem_manager procd-ujail \
uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 \
kmod-dwmac-intel kmod-e1000e kmod-e1000 kmod-forcedeth kmod-fs-vfat kmod-igb kmod-igc \
kmod-ixgbe kmod-r8169 kmod-tg3 kmod-drm-i915 luci kmod-mtk-t7xx kmod-phy-aquantia \
kmod-sfp kmod-wwan kmod-usb-net-rndis kmod-usb-serial kmod-usb-serial-option kmod-usb3 \
luci-proto-mbim luci-proto-ncm comgt pciutils usbutils block-mount \
ethtool-full iperf3 luci-i18n-base-zh-tw kmod-usb-net-cdc-mbim umbim picocom kmod-scsi-core \
kmod-block2mtd block-mount fdisk lsblk speedtest-go kmod-tcp-bbr luci-i18n-uhttpd-zh-tw \
luci-i18n-sqm-zh-tw luci-i18n-cloudflared-zh-tw luci-i18n-acme-zh-tw luci-app-uhttpd \
luci-app-sqm luci-app-acme \
"
PACKAGES="${PACKAGES} ${ADDITIONAL_PACKAGES}"

if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-tw"
    echo "Adding package: luci-i18n-dockerman-zh-tw"
fi

# ModemManager 相關套件 (可選)
if [ "$ENABLE_MODEM_MANAGER" = "yes" ]; then
  PACKAGES+=" modemmanager luci-proto-modemmanager"
fi


# Build profile
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/openwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."