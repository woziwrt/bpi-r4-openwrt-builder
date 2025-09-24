# Detailed information about the cellular modem

## network

```
/usr/share/modemdata/network.sh <network section>
```

## product

via serial port
```
/usr/share/modemdata/product.sh <device>
```

via ModemManager
```
/usr/share/modemdata/product_modemmanager.sh <device>
```

## connection parameters

via serial port

```
/usr/share/modemdata/params.sh <device> [0|1 force PLMN from file]
```

via ModemManager
```
/usr/share/modemdata/params_modemmanager.sh <device> [0|1 force PLMN from file]
```

via QMI/MBIM
```
/usr/share/modemdata/params_qmi.sh <device> [0|1 force PLMN from file] [0|1 MBIM device]
```

# Precompiled packages for stable release

https://dl.eko.one.pl/packages/opkg/all/

# Precompiled packages for development snapshots

https://dl.eko.one.pl/packages/apk/all/
