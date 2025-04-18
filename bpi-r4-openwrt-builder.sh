#!/bin/bash

#*****************************************************************************
#
# Build environment - Ubuntu 64-bit Server 24.04.2
#
# sudo apt update
# sudo apt install build-essential clang flex bison g++ gawk \
# gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
# python3-setuptools rsync swig unzip zlib1g-dev file wget
#
#*****************************************************************************

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt || true
cd openwrt; git checkout a51b1a98e026887ea4dd8f09a6fdc8138941e2ac; cd -;		#build: bpf: fix LLVM tool paths with host toolchain

git clone  https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds || true
cd mtk-openwrt-feeds; git checkout 224e13c7ed18d3e46dc89b1d1a670e1bf5ee6c1a; cd -;	#Fix WED 2.0 WDMA TX hang issue

echo "224e13c" > mtk-openwrt-feeds/autobuild/unified/feed_revision

#feeds modification
\cp -r my_files/w-feeds.conf.default openwrt/feeds.conf.default

### wireless-regdb modification - this remove all regdb wireless countries restrictions
rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
rm -rf mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
\cp -r my_files/500-tx_power.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
\cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

### jumbo frames support
\cp -r my_files/750-mtk-eth-add-jumbo-frame-support-mt7998.patch openwrt/target/linux/mediatek/patches-6.6

### tx_power patch - required for BE14 boards with defective eeprom flash
\cp -r my_files/99999_tx_power_check.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

### change sku_idx
\cp -r my_files/0184-wozi-fixup-mtk-hostapd-Add-txpower-vendor-command.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/network/services/hostapd/patches/0184-fixup-mtk-hostapd-Add-txpower-vendor-command.patch

### required & thermal zone 
\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch mtk-openwrt-feeds/24.10/patches-base/

sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/defconfig
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-bpi-r4 log_file=make

exit 0


########### After successful end of build #############


cd openwrt
# Basic config for bpi-r4
\cp -r ../configs/bpi-r4_basic_config .config

#Basic config for bpi-r4 poe
#\cp -r ../configs/bpi-r4-poe_basic_config .config

###### Then you can add all required additional feeds/packages ######### 

# qmi modems extension for example
\cp -r ../my_files/luci-app-3ginfo-lite-main/sms-tool/ feeds/packages/utils/sms-tool
\cp -r ../my_files/luci-app-3ginfo-lite-main/luci-app-3ginfo-lite/ feeds/luci/applications
\cp -r ../my_files/luci-app-modemband-main/luci-app-modemband/ feeds/luci/applications
\cp -r ../my_files/luci-app-modemband-main/modemband/ feeds/packages/net/modemband
\cp -r ../my_files/luci-app-at-socat/ feeds/luci/applications

./scripts/feeds update -a
./scripts/feeds install -a

####### And finally configure whatever you want ##########

make menuconfig
make -j$(nproc)


