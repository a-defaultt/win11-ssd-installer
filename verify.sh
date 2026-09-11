#!/usr/bin/env bash
# verify.sh /dev/sdX
# Requires a graphical session (-display gtk); it will fail on a headless host.
# That is intentional — a human is meant to watch this boot.
set -euo pipefail

DISK="${1:?usage: verify.sh /dev/sdX}"
WORK="$(mktemp -d)"
trap 'if [ -f "$WORK/swtpm.pid" ]; then kill "$(cat "$WORK/swtpm.pid")" 2>/dev/null || true; fi; rm -rf "$WORK"' EXIT INT TERM

[ -b "$DISK" ] || { echo "Not a block device: $DISK"; exit 1; }
[ -z "$(lsblk -no MOUNTPOINT "$DISK" | tr -d '[:space:]')" ] || { echo "Refusing: $DISK has mounted filesystems"; exit 1; }
[ -f /usr/share/OVMF/OVMF_CODE_4M.secboot.fd ] || { echo "Missing OVMF secure-boot firmware"; exit 1; }

mkdir -p "$WORK/tpm"
swtpm socket --tpmstate dir="$WORK/tpm" \
  --ctrl type=unixio,path="$WORK/swtpm-sock" --tpm2 \
  --pid file="$WORK/swtpm.pid" --daemon
cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd "$WORK/OVMF_VARS.fd"

echo "Booting $DISK directly — expect a normal Windows login screen for 'Admin'."
echo "Note: 'no bootable device' does NOT necessarily mean the install failed."
echo "This boots from a blank OVMF varstore (no NVRAM boot entry), so it needs the"
echo "UEFI removable fallback \\EFI\\Boot\\BOOTX64.EFI on the ESP, which Windows"
echo "does not always create. Fix by mounting the ESP and copying"
echo "\\EFI\\Microsoft\\Boot\\bootmgfw.efi to \\EFI\\Boot\\BOOTX64.EFI — no reinstall needed."
qemu-system-x86_64 \
  -enable-kvm -machine q35,smm=on -cpu host -m 4096 -smp 2 \
  -global driver=cfi.pflash01,property=secure,value=on \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
  -drive if=pflash,format=raw,file="$WORK/OVMF_VARS.fd" \
  -chardev socket,id=chrtpm,path="$WORK/swtpm-sock" \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -device ahci,id=ahci0 \
  -drive file="$DISK",format=raw,if=none,id=disk0 \
  -device ide-hd,drive=disk0,bus=ahci0.0 \
  -nic none \
  -vga std -display gtk
