include $(TOPDIR)/rules.mk
 
PKG_NAME:=atc-fib-fm350_gl
PKG_VERSION:=2025.02.01
PKG_RELEASE:=3

PKG_MAINTAINER:=Henrik Ginstmark <henrik@ginstmark.se>
PKG_LICENSE:=GPL-2.0


include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=AT command script for Fibocom FM350-GL
  SUBMENU:=WWAN
  PKGARCH:=all
  DEPENDS:=+kmod-usb-serial-option +kmod-usb-net-rndis +comgt
endef

define Package/$(PKG_NAME)/description
  AT command script for Fibocom FM350-GL
endef


define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ ! -d /etc/hotplug.d/usb ]
then
     mkdir /etc/hotplug.d/usb
fi
exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/lib/netifd/proto/atc.sh $(1)/lib/netifd/proto

	$(INSTALL_DIR) $(1)/etc/gcom
	$(INSTALL_DATA) ./files/etc/gcom/* $(1)/etc/gcom
endef
 
$(eval $(call BuildPackage,$(PKG_NAME)))
