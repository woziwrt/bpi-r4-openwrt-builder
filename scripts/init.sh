#!/bin/bash
echo "Init"
OPENWRT_BRANCH="openwrt-24.10"
OPENWRT_COMMIT="444299d70c12eb6b8543f990a62fbdd764798771" #kernel: backport mediatek WED DMA mask fixes
MTK_COMMIT="b65226d58ec5dc743de69c481745ef03188c4885" #[openwrt-master][common][u-boot][Add mt7981 and mt7986 U-boot support]

BASE_DIR="$(pwd)"
WORK_DIR="openwrt"
MTK_WORK_DIR="mtk-openwrt-feeds"
SOURCES_DIR="sources"
CONFIG_DIR="configs"
CONFIG_FILE="autobuild/unified/filogic/mac80211/mt7988_rfb/24.10/defconfig"
FEED_DIR="$SOURCES_DIR/my_feed"
GIT_DIR="$SOURCES_DIR/git"
REPO_LIST="$BASE_DIR/$CONFIG_DIR/extra_repos.txt"
COPY_RULES_LIST="$BASE_DIR/$CONFIG_DIR/extra_copy_rules.txt"
Y_LIST="$BASE_DIR/$CONFIG_DIR/enable_y.txt"
M_LIST="$BASE_DIR/$CONFIG_DIR/enable_m.txt"

repos=(
    "https://git.openwrt.org/openwrt/openwrt.git $WORK_DIR $OPENWRT_BRANCH $OPENWRT_COMMIT"
    "https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds $MTK_WORK_DIR '' $MTK_COMMIT"
)

copy_rules=()

# Add packages from workflow input to enable_y.txt
if [[ -n "$ADD_ENABLE_Y" ]]; then
    echo "$ADD_ENABLE_Y" | tr ',' '\n' >> "$Y_LIST"
fi

# Add packages from workflow input to enable_m.txt
if [[ -n "$ADD_ENABLE_M" ]]; then
    echo "$ADD_ENABLE_M" | tr ',' '\n' >> "$M_LIST"
fi

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

if [ ! -d "$BASE_DIR/$SOURCES_DIR" ]; then
    mkdir -p "$BASE_DIR/$SOURCES_DIR"
fi
if [ ! -d "$BASE_DIR/$GIT_DIR" ]; then
    mkdir -p "$BASE_DIR/$GIT_DIR"
fi
if [ ! -d "$BASE_DIR/$SOURCES_DIR/downloads" ]; then
    mkdir -p $BASE_DIR/$SOURCES_DIR/downloads
fi