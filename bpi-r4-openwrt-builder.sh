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
source ./scripts/init.sh
source $BASE_DIR/scripts/helpers.sh
source $BASE_DIR/scripts/clone.sh
source $BASE_DIR/scripts/copy.sh
source $BASE_DIR/scripts/patches.sh

echo "Go to $WORK_DIR"
cd $BASE_DIR/$WORK_DIR
source $BASE_DIR/scripts/packages.sh
echo "Start autobuild"
echo "$MTK_WORK_DIR/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make"
bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make