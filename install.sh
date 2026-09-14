#!/usr/bin/env bash
# install.sh /dev/sdX /path/to/win11pro.iso
set -euo pipefail

DISK="${1:?usage: install.sh /dev/sdX iso}"
ISO="${2:?usage: install.sh /dev/sdX iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'if [ -f "$WORK/swtpm.pid" ]; then kill "$(cat "$WORK/swtpm.pid")" 2>/dev/null || true; fi; rm -rf "$WORK"' EXIT INT TERM

[ "$EUID" -eq 0 ] || { echo "Run as root (sudo) — raw disk access requires it"; exit 1; }

for bin in qemu-system-x86_64 swtpm genisoimage sgdisk blkdiscard socat; do
  command -v "$bin" >/dev/null || { echo "Missing required tool: $bin"; exit 1; }
done
[ -f /usr/share/OVMF/OVMF_CODE_4M.secboot.fd ] || { echo "Missing OVMF secure-boot firmware"; exit 1; }
[ -f /usr/share/OVMF/OVMF_VARS_4M.ms.fd ] || { echo "Missing OVMF vars template"; exit 1; }
[ -f "$SCRIPT_DIR/unattend.xml" ] || { echo "Missing unattend.xml next to install.sh"; exit 1; }
[ -f "$ISO" ] || { echo "ISO not found: $ISO"; exit 1; }
[ -b "$DISK" ] || { echo "Not a block device: $DISK"; exit 1; }

lsblk -no TRAN "$DISK" | grep -q usb || { echo "Refusing: $DISK is not USB-attached"; exit 1; }
[ -z "$(lsblk -no MOUNTPOINT "$DISK" | tr -d '[:space:]')" ] || { echo "Refusing: $DISK has mounted filesystems"; exit 1; }
echo "Target: $DISK ($(lsblk -no SIZE "$DISK") on $(lsblk -no MODEL "$DISK"))"
read -rp "This WIPES $DISK completely. Type 'yes' to continue: " OK
[ "$OK" = yes ] || exit 1

# Build the answer-file ISO before touching the disk, so a genisoimage failure
# leaves the target untouched. Setup's windowsPE implicit search only looks for
# autounattend.xml at the root of removable media.
mkdir -p "$WORK/unattend_src"
cp "$SCRIPT_DIR/unattend.xml" "$WORK/unattend_src/autounattend.xml"
genisoimage -o "$WORK/unattend.iso" -J -R -V UNATTEND "$WORK/unattend_src" >/dev/null

wipefs -a "$DISK"
blkdiscard -f "$DISK" 2>/dev/null || sgdisk --zap-all "$DISK"

mkdir -p "$WORK/tpm"
swtpm socket --tpmstate dir="$WORK/tpm" \
  --ctrl type=unixio,path="$WORK/swtpm-sock" --tpm2 \
  --pid file="$WORK/swtpm.pid" --daemon
cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd "$WORK/OVMF_VARS.fd"

echo "Installing headless. If you want to watch, connect a VNC client"
echo "(e.g. Remmina) to 127.0.0.1:5901 — no password set."
qemu-system-x86_64 \
  -enable-kvm -machine q35,smm=on -cpu host -m 4096 -smp 2 \
  -global driver=cfi.pflash01,property=secure,value=on \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
  -drive if=pflash,format=raw,file="$WORK/OVMF_VARS.fd" \
  -chardev socket,id=chrtpm,path="$WORK/swtpm-sock" \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -device ahci,id=ahci0 \
  -drive file="$DISK",format=raw,if=none,id=disk0,cache=none \
  -device ide-hd,drive=disk0,bus=ahci0.0 \
  -drive file="$ISO",media=cdrom,if=none,id=cd0 \
  -device ide-cd,drive=cd0,bus=ahci0.1 \
  -drive file="$WORK/unattend.iso",media=cdrom,if=none,id=cd1 \
  -device ide-cd,drive=cd1,bus=ahci0.2 \
  -nic none \
  -boot once=d -display none -vnc 127.0.0.1:1 \
  -monitor unix:"$WORK/monitor.sock",server,nowait &
QEMU_PID=$!

# Windows Setup's UEFI boot stub shows "Press any key to boot from CD or
# DVD..." and silently falls through (eventually to PXE) if nothing arrives
# before its short, load-dependent timeout. Spam a keypress via the QEMU
# monitor instead of relying on a human to react in time.
for _ in $(seq 1 100); do
  if [ -S "$WORK/monitor.sock" ]; then
    echo "sendkey ret" | socat - "UNIX-CONNECT:$WORK/monitor.sock" >/dev/null 2>&1
  fi
  sleep 0.2
done

wait "$QEMU_PID"
echo "QEMU exited. Run $SCRIPT_DIR/verify.sh $DISK to confirm before shipping the disk."
