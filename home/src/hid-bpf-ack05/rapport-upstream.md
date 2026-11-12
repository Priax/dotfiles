# Upstream — https://gitlab.freedesktop.org/libevdev/udev-hid-bpf/-/issues

**Title:** XPPen ACK05: new firmware revision with different report descriptor lengths (214 / 175)

The ACK05 Shortcut Remote bundled with the XP-Pen Deco Pro XLW (Gen 2), USB 28bd:0202,
connected by cable, exposes three HID interfaces with these report descriptor lengths:

| interface | this unit | expected by XPPen__ACK05.bpf.c |
|---|---|---|
| 0 (mouse + keyboard) | 214 | 102 (`PAD_WIRED_DESCRIPTOR_LENGTH`) |
| 1 (stylus + mouse) | 175 | 109 (`STYLUS_DESCRIPTOR_LENGTH`) |
| 2 (vendor) | 36 | 36 (`VENDOR_DESCRIPTOR_LENGTH`) |

`probe()` returns -EINVAL for interfaces 0 and 1, so they are not disabled. Through the
bundled dongle the lengths are the known ones (177 / 109 / 36).

Adding 214 and 175 to the accepted lengths in `probe()` (so both get the disabled
descriptor) works: the vendor interface switches to raw mode and the remote is a working
tablet pad (10 buttons, dial, dial click) on kernel 7.3.3, KDE Plasma 6.8 Wayland.

I can provide `hid-recorder` output for the three interfaces if useful.
