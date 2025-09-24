#!/bin/sh

#
# (c) 2024-2025 Cezary Jackiewicz <cezary@eko.one.pl>
#
# (c) 2025 modified by Rafał Wabik - IceG - From eko.one.pl forum
#

DEVICE="$1"
VENDOR=""
PRODUCT=""

if [ -n "$DEVICE" ] && [ -e "$DEVICE" ]; then
    for SECTION in $(uci show defmodems | grep "=defmodems" | cut -d. -f2 | cut -d= -f1); do
        COMM_PORT=$(uci -q get "defmodems.${SECTION}.comm_uqmi")
        if [ "$COMM_PORT" = "$DEVICE" ]; then
            MODEM=$(uci -q get "defmodems.${SECTION}.modem")
            if [ -n "$MODEM" ]; then
                VENDOR=$(echo "$MODEM" | cut -d' ' -f1)
                PRODUCT=$(echo "$MODEM" | cut -d' ' -f2-)
            fi
            break
        fi
    done
fi

cat <<EOF
{
"vendor":"${VENDOR}",
"product":"${PRODUCT}",
"revision":"-",
"imei":"-",
"iccid":"-",
"imsi":"-"
}
EOF

exit 0
