#!/bin/bash

#*****************************************************************************
#
# Build environment - Ubuntu 64-bit Desktop 25.04
#
# sudo apt update
# sudo apt install build-essential clang flex bison g++ gawk \
# gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
# python3-setuptools rsync swig unzip zlib1g-dev file wget \
# libtraceevent-dev systemtap-sdt-dev libslang2-dev
#
#*****************************************************************************

OPENWRT_BRANCH="openwrt-24.10"
OPENWRT_COMMIT="444299d70c12eb6b8543f990a62fbdd764798771" #kernel: backport mediatek WED DMA mask fixes
MTK_COMMIT="b65226d58ec5dc743de69c481745ef03188c4885" #[openwrt-master][common][u-boot][Add mt7981 and mt7986 U-boot support]

BASE_DIR="$(pwd)"
WORK_DIR="openwrt"
MTK_WORK_DIR="mtk-openwrt-feeds"
SOURCES_DIR="sources"
FEED_DIR="$SOURCES_DIR/my_feed"
GIT_DIR="$SOURCES_DIR/git"

repos=(
    "https://git.openwrt.org/openwrt/openwrt.git $WORK_DIR $OPENWRT_BRANCH $OPENWRT_COMMIT"
    "https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds $MTK_WORK_DIR '' $MTK_COMMIT"
    "https://github.com/4IceG/luci-app-sms-tool-js.git luci-app-sms-tool-js"
    "https://github.com/4IceG/luci-app-lite-watchdog.git luci-app-lite-watchdog"
    "https://github.com/obsy/sms_tool.git sms_tool"
    "https://github.com/obsy/modemdata.git modemdata"
    "https://github.com/4IceG/luci-app-modemdata.git luci-app-modemdata"
)

copy_rules=(
    "sms_tool sms_tool/"
    "modemdata/modemdata modemdata/"
    "luci-app-modemdata/luci-app-modemdata luci-app-modemdata/"
    "luci-app-sms-tool-js/luci-app-sms-tool-js luci-app-sms-tool-js/"
    "luci-app-lite-watchdog/luci-app-lite-watchdog luci-app-lite-watchdog/"
)

# Create 'extra_repos.txt' file to add you own repos. Do not forget \n at the end
extras_file="extra_repos.txt"
if [ -f "$extras_file" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        repos+=("$line")
    done < "$extras_file"
fi

# Create 'extra_copy_rules.txt' copy packages from repos
extra_file="extra_copy_rules.txt"
if [ -f "$extra_file" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        copy_rules+=("$line")
    done < "$extra_file"
fi

clone_repo() {
    local repo_url="$1"
    local dest_dir="$2"
    local branch="$3"
    local ref="$4"

    if [[ -z "$repo_url" || -z "$dest_dir" ]]; then
        echo "Usage: clone_repo <repo_url> <dest_dir> [branch] [ref]"
        return 1
    fi

    if [[ -d "$dest_dir/.git" ]]; then
        echo "Folder '$dest_dir' already exists. Updating repo..."
        cd "$dest_dir" || return 1
        git fetch --all
        if [[ -n "$branch" ]]; then
            git reset --hard "origin/$branch"
        else
            git pull
        fi
    else
        echo "Cloning repo '$repo_url' to '$dest_dir'..."
        if [[ -n "$branch" ]]; then
            git clone --branch "$branch" "$repo_url" "$dest_dir" || return 1
        else
            git clone "$repo_url" "$dest_dir" || return 1
        fi
        cd "$dest_dir" || return 1
    fi

    if [[ -n "$ref" ]]; then
        echo "Switching to '$ref'..."
        git checkout "$ref" || return 1
    fi

    cd - >/dev/null || return 1
    chmod -R 755 "$dest_dir"
}

copy_dir() {
    local src="$1"
    local dst="$2"

    if [ -d "$src" ]; then
		echo "Removing "$dst"..."
        rm -rf "$dst"
    fi

    echo "Copying '$src' to '$dst'..."
    mkdir -p "$(dirname "$dst")"
    \cp -r "$src" "$dst"
}

if [ ! -d "$SOURCES_DIR" ]; then
    mkdir -p "$SOURCES_DIR"
fi
if [ ! -d "$FEED_DIR" ]; then
    mkdir -p "$FEED_DIR"
fi
if [ ! -d "$GIT_DIR" ]; then
    mkdir -p "$GIT_DIR"
fi

# Clone or check repos
for repo in "${repos[@]}"; do
    set -- $repo
    clone_repo "$1" "$GIT_DIR/$2" "$3" "$4"
done

copy_dir "$GIT_DIR/$WORK_DIR" "$WORK_DIR"
copy_dir "$GIT_DIR/$MTK_WORK_DIR" "$MTK_WORK_DIR"

# Copy packages
for rule in "${copy_rules[@]}"; do
    set -- $rule
	copy_dir "$GIT_DIR/$1" "$FEED_DIR/$2"
done

if [ ! -d "$GIT_DIR/$WORK_DIR/dl" ]; then
    mkdir -p "$WORK_DIR/dl"
fi
if [ -d "$WORK_DIR/dl" ]; then
    rm -rf "$WORK_DIR/dl"
fi
ln -s $BASE_DIR/$GIT_DIR/$WORK_DIR/dl $BASE_DIR/$WORK_DIR/dl

\cp -r my_files/w-rules $MTK_WORK_DIR/autobuild/unified/filogic/rules

### remove mtk strongswan uci support patch
rm -rf $MTK_WORK_DIR/24.10/patches-feeds/108-strongswan-add-uci-support.patch 

### wireless-regdb modification - this remove all regdb wireless countries restrictions
#rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
#rm -rf $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
#\cp -r my_files/500-tx_power.patch $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
#\cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

### tx_power patch - required for BE14 boards with defective eeprom flash
\cp -r my_files/99999_tx_power_check.patch $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

### required & thermal zone 
\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch $MTK_WORK_DIR/24.10/patches-base/

sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/defconfig
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

cd $WORK_DIR
bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make

exit 0

########### After successful end of build #############

\cp -r ../configs/config.mm .config
make menuconfig
make V=s -j$(nproc)



### Telit FN990 modem extension
 
cd $WORK_DIR
FEED_CONF="$BASE_DIR/$WORK_DIR/feeds.conf.default"
FEED_LINE="src-link $BASE_DIR/$FEED_DIR"

# Check line if it exists
if ! grep -Fxq "$FEED_LINE" "$FEED_CONF"; then
    echo "$FEED_LINE" >> "$FEED_CONF"
fi

./scripts/feeds update -a
./scripts/feeds install -a

\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto

####### And finally configure whatever you want ##########

\cp -r ../configs/modem_ext.config .config
make menuconfig
make V=s -j$(nproc)


