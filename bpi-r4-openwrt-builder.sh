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
CONFIG_DIR="configs"
CONFIG_FILE="$BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig"
FEED_DIR="$BASE_DIR/$SOURCES_DIR/my_feed"
GIT_DIR="$BASE_DIR/$SOURCES_DIR/git"
REPO_LIST="$BASE_DIR/$CONFIG_DIR/extra_repos.txt"
COPY_RULES_LIST="$BASE_DIR/$CONFIG_DIR/extra_copy_rules.txt"
Y_LIST="$BASE_DIR/$CONFIG_DIR/enable_y.txt"
M_LIST="$BASE_DIR/$CONFIG_DIR/enable_m.txt"

repos=(
    "https://git.openwrt.org/openwrt/openwrt.git $WORK_DIR $OPENWRT_BRANCH $OPENWRT_COMMIT"
    "https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds $MTK_WORK_DIR '' $MTK_COMMIT"
)

copy_rules=(
    "$GIT_DIR/$WORK_DIR $WORK_DIR"
    "$GIT_DIR/$MTK_WORK_DIR $MTK_WORK_DIR"
)

export XZ_DEFAULTS="--memlimit=12GiB"

# Create 'extra_repos.txt' file to add you own repos. Do not forget \n at the end
if [ -f "$REPO_LIST" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        repos+=("$line")
    done < "$REPO_LIST"
fi

# Create 'extra_copy_rules.txt' copy packages from repos
if [ -f "$COPY_RULES_LIST" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        copy_rules+=("$line")
    done < "$COPY_RULES_LIST"
fi

clone_repo() {
    local repo_url="$1"
    local dest_dir="$2"
    local branch="$3"
    local clean_branch=$(echo "$branch" | sed 's/^['"'"'"]*//; s/['"'"'"]*$//')
    local ref="$4"

    if [[ -z "$repo_url" || -z "$dest_dir" ]]; then
        echo "Usage: clone_repo <repo_url> <dest_dir> [branch] [ref]"
        return 1
    fi

    if [[ -d "$dest_dir/.git" ]]; then
        echo "Folder '$dest_dir' already exists. Updating repo..."
        cd "$dest_dir" || return 1
        git fetch --all
        if [[ -n "$clean_branch" ]]; then
            git reset --hard "origin/$clean_branch"
        else
            git reset --hard
            git pull
        fi
    else
        echo "Cloning repo '$repo_url' to '$dest_dir'..."
        if [[ -n "$clean_branch" ]]; then
            git clone --branch "$clean_branch" "$repo_url" "$dest_dir" || return 1
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
if [ ! -d "$GIT_DIR" ]; then
    mkdir -p "$GIT_DIR"
fi
rm -rf "$FEED_DIR"
mkdir -p "$FEED_DIR"

# Clone or check repos
for repo in "${repos[@]}"; do
    set -- $repo
    clone_repo "$1" "$GIT_DIR/$2" "$3" "$4"
done

# Fix MIHOMO package
sed -i 's/^PKG_VERSION:=stable$/PKG_VERSION:=1.19.16/' $BASE_DIR/$GIT_DIR/mihomo-openwrt/net/mihomo/Makefile

# Copy packages
for rule in "${copy_rules[@]}"; do
    set -- $rule
    copy_dir "$GIT_DIR/$1" "$FEED_DIR/$2"
done

# Prevents to redownload packages
if [ ! -d "$GIT_DIR/$WORK_DIR/dl" ]; then
    mkdir -p $BASE_DIR/$GIT_DIR/$WORK_DIR/dl
	echo "mkdir -p $BASE_DIR/$GIT_DIR/$WORK_DIR/dl"
fi
if [ -d "$WORK_DIR/dl" ]; then
    rm -rf $WORK_DIR/dl
	echo "rm -rf $WORK_DIR/dl"
fi

ln -s $BASE_DIR/$GIT_DIR/$WORK_DIR/dl $BASE_DIR/$WORK_DIR/dl
echo "ln -s $BASE_DIR/$GIT_DIR/$WORK_DIR/dl $BASE_DIR/$WORK_DIR/dl"

\cp -r my_files/w-rules $MTK_WORK_DIR/autobuild/unified/filogic/rules

### remove mtk strongswan uci support patch
rm -rf $MTK_WORK_DIR/24.10/patches-feeds/108-strongswan-add-uci-support.patch 

### wireless-regdb modification - this remove all regdb wireless countries restrictions
rm -rf $BASE_DIR/$WORK_DIR/package/firmware/wireless-regdb/patches/*.*
rm -rf $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
cp -r my_files/500-tx_power.patch $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
cp -r my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

### tx_power patch - required for BE14 boards with defective eeprom flash
\cp -r my_files/99999_tx_power_check.patch $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

### required & thermal zone 
\cp -r my_files/1007-wozi-arch-arm64-dts-mt7988a-add-thermal-zone.patch $MTK_WORK_DIR/24.10/patches-base/

sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/defconfig
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' $MTK_WORK_DIR/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

rm -rf $BASE_DIR/$WORK_DIR/files
mkdir -p $BASE_DIR/$WORK_DIR/files
\cp -r $BASE_DIR/my_files/files/* $BASE_DIR/$WORK_DIR/files/

\cp -r $BASE_DIR/my_files/qmi.sh $BASE_DIR/$WORK_DIR/package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 $BASE_DIR/$WORK_DIR/package/network/utils/uqmi/files/lib/netifd/proto

# Add extra feed
FEED_CONF="$BASE_DIR/$WORK_DIR/feeds.conf.default"
FEED_LINE="src-link my_feed $BASE_DIR/$FEED_DIR"

# Check line if it exists
if ! grep -Fxq "$FEED_LINE" "$FEED_CONF"; then
    echo "$FEED_LINE" >> "$FEED_CONF"
fi

cd $WORK_DIR

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