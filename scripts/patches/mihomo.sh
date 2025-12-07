#!/bin/bash
echo "Fix mihomo package version"
sed -i 's/^PKG_VERSION:=stable$/PKG_VERSION:=1.19.16/' $BASE_DIR/$FEED_DIR/mihomo/Makefile