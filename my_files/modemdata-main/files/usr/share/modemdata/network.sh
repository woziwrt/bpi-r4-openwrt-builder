#!/bin/sh

#
# (c) 2024-2025 Cezary Jackiewicz <cezary@eko.one.pl>
#

NETWORK=$1
if [ -n "$NETWORK" ]; then
	UP=""
	CT=""
	IFACE=""
	eval $(ifstatus ${NETWORK} | jsonfilter -q -e 'UP=@.up' -e 'CT=@.uptime' -e 'IFACE=@.l3_device')
	if [ "x$UP" = "x1" ]; then
		STATUS="CONNECTED"
		if [ -n "$IFACE" ]; then
			RX=$(ifconfig $IFACE | awk -F[\(\)] '/bytes/ {printf "%s",$2}')
			TX=$(ifconfig $IFACE | awk -F[\(\)] '/bytes/ {printf "%s",$4}')
		fi
	else
		STATUS="DISCONNECTED"
	fi
fi

cat <<EOF
{
"status": "${STATUS}",
"conn_time_sec": "${CT}",
"rx": "${RX}",
"tx": "${TX}"
}
EOF

exit 0
