#!/bin/sh

#
# Copyright 2020-2022 Rafał Wabik (IceG) - From eko.one.pl forum
# Licensed to the GNU General Public License v3.0.

chmod +x /usr/bin/luci-app-atinout
rm -rf /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/

work=false
for port in /dev/ttyUSB*
do
    [[ -e $port ]] || continue
    gcom -d $port info &> /tmp/testusb
    testUSB=`cat /tmp/testusb | grep "Error\|Can't"`
    if [ -z "$testUSB" ]; then 
        work=$port
        break
    fi
done
rm -rf /tmp/testusb

if [ $work != false ]; then
uci set atinout.@atinout[0].atcport=$work
uci commit atinout
fi
