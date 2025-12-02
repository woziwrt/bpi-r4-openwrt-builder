#!/bin/bash
echo "Wireless-regdb modification - this remove all regdb wireless countries restrictions"
rm -rf $BASE_DIR/$WORK_DIR/package/firmware/wireless-regdb/patches/*.*
rm -rf $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
cp -r $BASE_DIR/my_files/500-tx_power.patch $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches
cp -r $BASE_DIR/my_files/regdb.Makefile $BASE_DIR/$WORK_DIR/package/firmware/wireless-regdb/Makefile