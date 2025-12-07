#!/bin/bash
echo "Apply patches"
source $BASE_DIR/scripts/patches/wrules.sh
source $BASE_DIR/scripts/patches/mihomo.sh
source $BASE_DIR/scripts/patches/strongswan.sh
#source $BASE_DIR/scripts/patches/regdb.sh
source $BASE_DIR/scripts/patches/tx_power.sh
source $BASE_DIR/scripts/patches/thermal.sh
source $BASE_DIR/scripts/patches/autobuild.sh
source $BASE_DIR/scripts/patches/files.sh
#source $BASE_DIR/scripts/patches/qmi.sh
source $BASE_DIR/scripts/patches/my_feed.sh
