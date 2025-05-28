#!/bin/bash

#*****************************************************************************
#
# Build environment - Ubuntu 64-bit Server 24.04.2
#
# sudo apt update
# sudo apt install build-essential clang flex bison g++ gawk \
# gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
# python3-setuptools rsync swig unzip zlib1g-dev file wget \
# libtraceevent-dev systemtap-sdt-dev libslang-dev
#
#*****************************************************************************

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt || true
cd openwrt; git checkout 0ccd68f9baedc3c9515694a4f77872ff54b53d9c; cd -;		#mac80211: brcm: update RPi brcmfmac patches

git clone  https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds || true
cd mtk-openwrt-feeds; git checkout e1fc3a0c3b96d6e292cb2f73ddebdbd77deb663b; cd -;	#Add network support for mt7531 switch P5 to the MT7987

echo "e1fc3a0" > mtk-openwrt-feeds/autobuild/unified/feed_revision

#\cp -r configs/defconfig mtk-openwrt-feeds/autobuild/unified/filogic/24.10/defconfig
\cp -r configs/dbg_defconfig mtk-openwrt-feeds/autobuild/unified/filogic/24.10/defconfig

#feeds modification
#\cp -r my_files/w-feeds.conf.default openwrt/feeds.conf.default



### wireless-regdb modification - this remove all regdb wireless countries restrictions
#rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
#rm -rf mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
#\cp -r my_files/500-tx_power.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
#\cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

### adds a frequency match check to ensure the noise value corresponds to the interface's actual frequency for multiple radios under a single wiphy
\cp -r my_files/200-wozi-libiwinfo-fix_noise_reading_for_radios.patch openwrt/package/network/utils/iwinfo/patches

### tx_power patch - required for BE14 boards with defective eeprom flash
#\cp -r my_files/99999_tx_power_check.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

### tx_power patch - by dan pawlik
\cp -r my_files/99999_tx_power_check_by_dan_pawlik.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

### remove mtk strongswan uci support patch
#rm -rf mtk-openwrt-feeds/24.10/patches-feeds/108-strongswan-add-uci-support.patch

### required & thermal zone 
\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch mtk-openwrt-feeds/24.10/patches-base/

#sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/defconfig
#sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
#sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

export NO_JEVENTS=1

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make

exit 0


########### After successful end of build #############

## IMPORTANT NOTE !!!!!
## Do not change Target Profile from Multiple devices to other  !!!
## Do not remove MediaTek MT7988A rfb and MediaTek MT7988D rfb from Target Devices !!! 

#################

cd openwrt
# Basic config
\cp -r ../configs/rc1_ext_mm_config .config


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


