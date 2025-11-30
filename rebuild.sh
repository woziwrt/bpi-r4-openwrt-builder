#!/bin/bash
BASE_DIR="$(pwd)"
WORK_DIR="openwrt"
MTK_WORK_DIR="mtk-openwrt-feeds"
CONFIG_DIR="configs"
CONFIG_FILE="$BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig"
Y_LIST="$BASE_DIR/$CONFIG_DIR/enable_y.txt"
M_LIST="$BASE_DIR/$CONFIG_DIR/enable_m.txt"

export XZ_DEFAULTS="--memlimit=12GiB"

cd $WORK_DIR
bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh clean

# enable "y" flags
if [ -f "$Y_LIST" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        sed -i "/CONFIG_PACKAGE_${pkg}=.*/d" "$CONFIG_FILE"
        echo "CONFIG_PACKAGE_${pkg}=y" >> "$CONFIG_FILE"
    done < $Y_LIST
fi

# enable "m" flags
if [ -f "$M_LIST" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        sed -i "/CONFIG_PACKAGE_${pkg}=.*/d" "$CONFIG_FILE"
        echo "CONFIG_PACKAGE_${pkg}=m" >> "$CONFIG_FILE"
    done < $M_LIST
fi

bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make