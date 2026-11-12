# Correctif HID-BPF de la télécommande XP-Pen ACK05, recompilé pour le noyau en cours.
# Source: drivers/hid/bpf/progs/ du noyau Linux (copie d'origine dans kernel/), plus les tailles
# de descripteurs de la révision récente. À refaire si un noyau futur refuse de le charger:
#   make clean && make && sudo make install
OBJ := 0010-XPPen__ACK05.bpf.o

all: $(OBJ)

include/vmlinux.h:
	bpftool btf dump file /sys/kernel/btf/vmlinux format c > $@

$(OBJ): 0010-XPPen__ACK05.bpf.c include/vmlinux.h
	clang -g -O2 --target=bpf -Wall -Werror -Wno-microsoft-anon-tag -fms-extensions \
		-Iinclude -Ikernel -c $< -o $@
	llvm-strip -g $@

# Pose le fichier dans /etc/udev-hid-bpf et une règle udev qui le charge au branchement.
# (Le paquet Fedora cherche d'abord sa propre version dans /usr/lib/firmware/hid/bpf.)
install: $(OBJ)
	udev-hid-bpf install --force $(OBJ)

uninstall:
	rm -f /etc/udev-hid-bpf/$(OBJ) /etc/udev/rules.d/99-hid-bpf-0010-XPPen__ACK05.rules

clean:
	rm -f $(OBJ) include/vmlinux.h

.PHONY: all install uninstall clean
