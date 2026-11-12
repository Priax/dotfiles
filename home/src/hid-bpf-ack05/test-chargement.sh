#!/bin/bash
# Charge le correctif recompilé sur la télécommande branchée (à lancer avec sudo), sans rien
# installer: débrancher / rebrancher la télécommande revient à l'état d'avant.
dir=$(dirname "$(readlink -f "$0")")
out=${1:-/dev/stdout}
{
    for d in /sys/bus/hid/devices/0003:28BD:0202.*; do
        echo "== $(basename "$d") (descripteur de $(wc -c <"$d/report_descriptor") octets)"
        udev-hid-bpf --verbose add --replace "$d" "$dir/0010-XPPen__ACK05.bpf.o" 2>&1 | grep -v 'DEBUG' | tail -8
    done
    sleep 2
    echo "== programmes chargés"
    ls -R /sys/fs/bpf/hid 2>&1 | head -30
    echo "== périphériques d'entrée de la télécommande"
    for d in /sys/bus/hid/devices/0003:28BD:0202.*; do
        echo "$(basename "$d") taille=$(wc -c <"$d/report_descriptor") entrées=$(for i in "$d"/input/input*; do [ -e "$i" ] && printf '%s[%s] ' "$(basename "$i")" "$(cat "$i/name")"; done)"
    done
    for e in /dev/input/event*; do
        udevadm info "$e" | grep -q 'ID_MODEL_ID=0202' && echo "$e: $(udevadm info "$e" | grep -E 'ID_INPUT_[A-Z_]+=1' | sed 's/E: //' | tr '\n' ' ')"
    done
    echo "== noyau"
    dmesg | tail -25 | grep -iE 'bpf|0202|shortcut|hid' | tail -15
} >"$out" 2>&1
[ "$out" != /dev/stdout ] && chmod 644 "$out"
echo "terminé"
