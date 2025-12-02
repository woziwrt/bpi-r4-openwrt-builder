#!/bin/bash
echo "Disable perf package from autobild"
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/defconfig
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $BASE_DIR/$MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $BASE_DIR/$MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config