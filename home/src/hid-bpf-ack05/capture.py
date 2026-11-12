#!/usr/bin/env python3
"""Écoute la télécommande ACK05 (sudo): événements d'entrée vus par le système, et rapports
bruts HID du canal vendeur. Lecture seule."""
import glob, os, re, select, struct, sys, time

DUREE = int(sys.argv[1]) if len(sys.argv) > 1 else 25
SORTIE = sys.argv[2] if len(sys.argv) > 2 else None
noms = {}
for ligne in open("/usr/include/linux/input-event-codes.h"):
    m = re.match(r"#define\s+((?:KEY|BTN)_\w+)\s+(0x[0-9a-fA-F]+|\d+)\s", ligne)
    if m:
        noms.setdefault(int(m.group(2), 0), m.group(1))

fds = {}
for bloc in open("/proc/bus/input/devices").read().split("\n\n"):
    nom = re.search(r'N: Name="(.*)"', bloc)
    ev = re.search(r"H: Handlers=.*?(event\d+)", bloc)
    if nom and ev and "Shortcut Remote" in nom.group(1):
        fds[os.open("/dev/input/" + ev.group(1), os.O_RDONLY | os.O_NONBLOCK)] = ("ev", ev.group(1) + " " + nom.group(1)[-8:])
for h in glob.glob("/sys/class/hidraw/hidraw*"):
    if "28BD:0202" in os.readlink(h + "/device"):
        taille = os.path.getsize(h + "/device/report_descriptor") if False else len(open(h + "/device/report_descriptor", "rb").read())
        fds[os.open("/dev/" + os.path.basename(h), os.O_RDONLY | os.O_NONBLOCK)] = ("raw", f"{os.path.basename(h)} (desc {taille})")

lignes = []
def dire(t):
    print(t, flush=True)
    lignes.append(t)

dire(f"{len(fds)} sources écoutées pendant {DUREE} s: " + ", ".join(v[1] for v in fds.values()))
FORMAT, fin, n = "llHHi", time.time() + DUREE, 0
while time.time() < fin and n < 200:
    for fd in select.select(list(fds), [], [], 0.5)[0]:
        genre, nom = fds[fd]
        try:
            d = os.read(fd, 4096)
        except OSError:
            continue
        if genre == "raw":
            n += 1
            dire(f"[{nom}] brut: {d.hex(' ')}")
            continue
        for i in range(0, len(d), struct.calcsize(FORMAT)):
            _, _, typ, code, val = struct.unpack_from(FORMAT, d, i)
            if typ in (1, 2, 3):
                n += 1
                quoi = noms.get(code, code) if typ == 1 else (f"REL_{code}" if typ == 2 else f"ABS_{code}")
                dire(f"[{nom}] {quoi} = {val}")
dire("fini.")
if SORTIE:
    open(SORTIE, "w").write("\n".join(lignes) + "\n")
    os.chmod(SORTIE, 0o644)
