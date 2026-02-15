#!/bin/bash
set -euo pipefail

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt
cd openwrt; git checkout 5774c8b316eff80070775ee695d998ad3ee828d1; cd -;		#mediatek: add Motorcomm PHY support to Cudy AP3000 v1

git clone --branch master https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds
cd mtk-openwrt-feeds; git checkout e39de5680a2e945a6d420e9f9f95cef8d4f99506; cd -;	#[openwrt-24][MAC80211][WiFi7][Update MP4.2 critical patches]

### wireless-regdb modification - this remove all regdb wireless countries restrictions
#rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
#rm -rf mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
#\cp -r my_files/500-tx_power.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
#\cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

rm -rf mtk-openwrt-feeds/24.10/patches-feeds/108-strongswan-add-uci-support.patch

\cp -r my_files/9999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/24.10/files/target/linux/mediatek/patches-6.6

### tx_power patch - required for BE14 boards with defective eeprom flash
\cp -r my_files/99999_tx_power_check.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/
\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch mtk-openwrt-feeds/24.10/patches-base/

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 prepare

\cp -r ../my_files/sms-tool/ feeds/packages/utils/sms-tool
\cp -r ../my_files/modemdata-main/ feeds/packages/utils/modemdata 
\cp -r ../my_files/luci-app-modemdata-main/luci-app-modemdata/ feeds/luci/applications
\cp -r ../my_files/luci-app-lite-watchdog/ feeds/luci/applications
\cp -r ../my_files/luci-app-sms-tool-js-main/luci-app-sms-tool-js/ feeds/luci/applications

./scripts/feeds update -a
./scripts/feeds install -a

\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto
chmod -R 755 feeds/luci/applications/luci-app-modemdata/root
chmod -R 755 feeds/luci/applications/luci-app-sms-tool-js/root
chmod -R 755 feeds/packages/utils/modemdata/files/usr/share

#cd openwrt
\cp -r ../my_files/my_final_defconfig .config
make defconfig

bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 build

