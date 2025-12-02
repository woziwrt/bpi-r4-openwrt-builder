#!/bin/bash
echo "tx_power patch - required for BE14 boards with defective eeprom flash"
\cp -r $BASE_DIR/my_files/99999_tx_power_check.patch $BASE_DIR/$MTK_WORK_DIR/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/