#!/bin/bash
echo "Apply packages"
echo "Reset $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig"
cp -r $BASE_DIR/$GIT_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig

# enable "y" flags
if [ -f "$Y_LIST" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        echo "Apply CONFIG_PACKAGE_${pkg}=y"
        sed -i "/CONFIG_PACKAGE_${pkg}=.*/d" "$BASE_DIR/$MTK_WORK_DIR/$CONFIG_FILE"
        echo "CONFIG_PACKAGE_${pkg}=y" >> "$BASE_DIR/$MTK_WORK_DIR/$CONFIG_FILE"
    done < $Y_LIST
fi

# enable "m" flags
if [ -f "$M_LIST" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        echo "Apply CONFIG_PACKAGE_${pkg}=y"
        sed -i "/CONFIG_PACKAGE_${pkg}=.*/d" "$BASE_DIR/$MTK_WORK_DIR/$CONFIG_FILE"
        echo "CONFIG_PACKAGE_${pkg}=m" >> "$BASE_DIR/$MTK_WORK_DIR/$CONFIG_FILE"
    done < $M_LIST
fi