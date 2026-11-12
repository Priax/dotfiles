# Bugzilla Fedora — composant `udev-hid-bpf`, version 44

**Summary:** XPPen ACK05 BPF program fails to load on kernel 7.3 (bpf_wq_set_callback_impl prototype mismatch)

**Description of problem:**
The prebuilt `0010-XPPen__ACK05.bpf.o` shipped in udev-hid-bpf can no longer be loaded on
kernel 7.3: libbpf rejects it because the `bpf_wq_set_callback_impl` kfunc prototype it was
built against does not match the running kernel. The XP-Pen ACK05 shortcut remote therefore
stays in its firmware keyboard mode and is not exposed as a tablet pad.

**Version-Release number of selected component:**
udev-hid-bpf-2.2.0.20251121-4.fc44.x86_64
kernel 7.3.3-200.fc44.x86_64, libbpf 1.6.3

**How reproducible:** always

**Steps to Reproduce:**
1. Plug in an XP-Pen ACK05 Shortcut Remote (USB 28bd:0202)
2. `sudo udev-hid-bpf --verbose --debug add /sys/bus/hid/devices/0003:28BD:0202.XXXX`

**Actual results:**
```
libbpf: WARN libbpf: extern (func ksym) 'bpf_wq_set_callback_impl': func_proto [201] incompatible with vmlinux [46700]
udev_hid_bpf::hidudev: WARN Failed to load "/usr/lib/firmware/hid/bpf/0010-XPPen__ACK05.bpf.o": Invalid argument (os error 22)
```
`/sys/fs/bpf/hid` does not exist, no tablet pad device is created.

**Expected results:**
The program loads and the remote shows up as a tablet pad (10 buttons + dial).

**Additional info:**
Rebuilding `drivers/hid/bpf/progs/XPPen__ACK05.bpf.c` from the v7.3 kernel tree (which uses
`bpf_wq_set_callback`) against the running kernel's BTF produces an object that loads fine
and makes the remote work as a pad in KDE Plasma. Any other program in the package using
`hid_bpf_async.h` is probably affected the same way.
