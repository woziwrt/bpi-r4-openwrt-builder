#!/bin/bash
source ./scripts/init.sh

cd $WORK_DIR
bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh clean
source $BASE_DIR/scripts/patches.sh
source $BASE_DIR/scripts/packages.sh
bash ../$MTK_WORK_DIR/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make