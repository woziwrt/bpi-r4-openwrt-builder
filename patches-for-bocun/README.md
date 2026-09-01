# RTL8261BE copper SFP+ on BPI-R4 — patch set

Prepared for Bo-Cun Chen (MediaTek), 2026-08-29, in the thread
*"Heads-up + fix: mtk-lynxi link_poll reports link-up with unresolved speed"*.

These are the exact files from our builder — byte for byte, not re-exported.

## The hardware problem

The module is an **OEM SFP-10G-T (Realtek RTL8261BE-CG)**: a pure copper 10G
media converter. Two properties drive everything below.

1. **It has no I2C-to-MDIO bridge.** There is no PHY behind I2C for the kernel
   to attach to. It negotiates on the line side itself and signals link through
   the SFP pins.
2. **It rewrites its own EEPROM identity by line speed.** Cold it advertises
   10GBASE-T; once it locks a 1G copper partner it re-advertises as a different
   part number:

   | state | Vendor PN | caps |
   |---|---|---|
   | cold / 10G partner | `SFP-10G-T` | `0x00007440` |
   | after locking 1G | `SFP-10G-T-I` | `0x00006440` |

   Same physical module, same serial. The host reads the EEPROM **once** at
   probe time, so if it probed while the module still claimed 10G, it selects
   10GBASE-R and never links.

## The patches

Apply in this order.

| # | file | what it does |
|---|---|---|
| 1 | `999-sfp-11-rtl8261be-mdio-none.patch` | probe for the RollBall I2C-to-MDIO bridge; fall back to `MDIO_I2C_NONE` when absent, so the SFP layer stops waiting for a PHY that never answers |
| 2 | `999-sfp-22-rtl8261be-boot-1g-reprobe.patch` | watchdog: if the link is not stable within `T_LINK_FAIL` (15 s), re-read the module and re-select the host interface. Bounded to 20 retries. Handles property 2 above |
| 3 | `999-pcs-10-lynxi-hold-link-down-on-invalid-speed.patch` | `pcs-mtk-lynxi`: never report link-up while the speed is unresolved. One-line guard in `mtk_pcs_lynxi_update_state()` |
| 4 | `999-eth-21-mtk-gdm-rx-fsm-reset.patch` | pulse the Rx FIFO clear in `mtk_gdm_mac_link_up()`; clears a GMAC Rx FSM left stuck after a 10G→1G mode change (`MAC_FSM` Rx nibble `0x08` instead of `0x01`, Rx DMA wedged) |

### Upstream status — please read before taking #1

Patch 1 was merged upstream as `8fe125892f40` on 2026-06-02 and **I reverted it
myself** on 2026-06-29 as `b521003c27eb`.

The probe ran in `SFP_S_INIT`, i.e. **before genuine RollBall modules finish
their firmware init**. Those modules did not answer `CMD_READ`/`CMD_DONE` in
time, the probe timed out, `MDIO_I2C_NONE` was set, and real RollBall modules
then never got a PHY. Maxime Chevallier and Aleksander Bajkowski confirmed the
regression on genuine RollBall hardware.

For the RTL8261BE the logic is correct and we carry it downstream, but
**do not push it into a shared SDK as-is** — it regresses genuine RollBall
modules. A correct upstream fix has to defer the probe past module init.

Patches 2–4 were never submitted upstream. Patch 3 was sent to MediaTek
directly on 2026-07-08 (`md5 1093b548c84d5968aeef20d52acbb7be`).

## Tested on

- board: **standard BPI-R4** (MT7988A), WAN SFP cage
- kernel **6.12.103**, OpenWrt 25.12-SNAPSHOT
- module: OEM `SFP-10G-T`, serial `2511140049`, RTL8261BE-CG inside

Results, 2026-08-29, all four patches applied:

| scenario | result |
|---|---|
| boot with 10G cable | Link Up 10Gbps/Full, 95 min, `rx_errors=0` |
| boot with 1G cable | re-read at `t=35 s` → `1000base-x` → Link Up 1Gbps/Full at `t=50 s` |
| runtime 1G → 10G (cable swap while running) | 22 s to Link Up 10Gbps/Full |
| hot-plug (remove + reinsert module) | 8 s to Link Up 10Gbps/Full |

Across all of it: `rx_errors=0`, `tx_errors=0`, **no "GMAC Rx hang"**, **no
"Link is Up - Unsupported"**.

Throughput is only shown at 1 Gbit/s (`948 Mbit/s`, iperf3, 4 streams) because
every link partner available here is 1G — the 10G side is a switch with no 10G
host behind it.

---

# Unrelated: aqr113c MIB thread lifetime

Added 2026-09-01, after the thread *"aqr113c MIB thread panics the board when the
PHY goes away"*. It has nothing to do with the SFP set above — different driver,
different failure — and applies on top of
`999-ephy-aqr113c-04-add-mib-debugfs.patch` in mtk-openwrt-feeds.

| file | what it does |
|---|---|
| `999-ephy-zz-01-fix-aqr-mib-thread-lifetime.patch` | adds the `.remove` handler `aqr107_probe()` never had, so `kthread_stop()` is finally called; also closes two leaks in the same path (`debugfs_remove()` on the file that holds `phydev`, and the `dput()` that `debugfs_lookup()` requires) |

`aqr107_mib_thread` dereferences the `phy_device` once a second and nothing ever
stopped it, so removing an AQR113C module from a running cage panicked the board
every time (BPI-R4, 6.12.103). With the patch the same action logs only
`module removed` / `Link is Down` and the board stays up — verified three times
in a row on the same boot.

`aqr107_probe()` is shared by 14 PHY drivers, so all of them need the handler.
