#!/bin/sh

#
# (c) 2025 Cezary Jackiewicz <cezary@eko.one.pl>
#

VENDOR=""
PRODUCT=""
REVISION=""
IMEI=""
ICCID=""
IMSI=""
SIM=""

DEVICE=$1
if [ -n "$DEVICE" ]; then
	eval $(mmcli -m "$DEVICE" -J 2>/dev/null | jsonfilter -q -e 'IMEI=@.modem.generic["equipment-identifier"]' -e 'VENDOR=@.modem.generic.manufacturer' -e 'PRODUCT=@.modem.generic.model' -e 'REVISION=@.modem.generic.revision' -e 'SIM=@.modem.generic.sim')
	[ -n "$SIM" ] && eval $(mmcli -m "$DEVICE" -J --sim $SIM 2>/dev/null | jsonfilter -q -e 'ICCID=@.sim.properties.iccid' -e 'IMSI=@.sim.properties.imsi')
fi

cat <<EOF
{
"vendor":"${VENDOR}",
"product":"${PRODUCT}",
"revision":"${REVISION}",
"imei":"${IMEI}",
"iccid":"${ICCID}",
"imsi":"${IMSI}"
}
EOF

exit 0
