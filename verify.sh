#!/usr/bin/env bash
# verify.sh /dev/sdX
set -euo pipefail

DISK="${1:?usage: verify.sh /dev/sdX}"
WORK="$(mktemp -d)"
trap 'if [ -f "$WORK/swtpm.pid" ]; then kill "$(cat "$WORK/swtpm.pid")" 2>/dev/null || true; fi; rm -rf "$WORK"' EXIT

[ -b "$DISK" ] || { echo "Not a block device: $DISK"; exit 1; }
[ -f /usr/share/OVMF/OVMF_CODE_4M.secboot.fd ] || { echo "Missing OVMF secure-boot firmware"; exit 1; }

mkdir -p "$WORK/tpm"
swtpm socket --tpmstate dir="$WORK/tpm" \
  --ctrl type=unixio,path="$WORK/swtpm-sock" --tpm2 \
  --pid file="$WORK/swtpm.pid" --daemon
cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd "$WORK/OVMF_VARS.fd"

echo "Booting $DISK directly — expect a normal Windows login screen for 'Admin'."
qemu-system-x86_64 \
  -enable-kvm -machine q35,smm=on -cpu host -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
  -drive if=pflash,format=raw,file="$WORK/OVMF_VARS.fd" \
  -chardev socket,id=chrtpm,path="$WORK/swtpm-sock" \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -device ahci,id=ahci0 \
  -drive file="$DISK",format=raw,if=none,id=disk0 \
  -device ide-hd,drive=disk0,bus=ahci0.0 \
  -vga std -display gtk
