# win11-ssd-installer

Installs Windows 11 Pro fully unattended onto an external USB SSD, using QEMU/KVM
with UEFI Secure Boot firmware and an emulated TPM 2.0, so the resulting disk boots
on real hardware. The install never gets network access.

## Prerequisites

- Packages: `qemu-system-x86`, `ovmf`, `swtpm`, `swtpm-tools`, `gdisk`, `genisoimage`
  (already present on the target machine; listed here for anyone else).
- Root: `install.sh` writes raw to the block device and refuses to run without it.
- A Windows 11 Pro ISO (the image index in `unattend.xml` is pinned to that ISO).
- `verify.sh` needs a graphical session; it opens a real QEMU window on purpose.

## Usage

```
sudo ./install.sh /dev/sdX /path/to/windows.iso   # ~20-30 min with KVM
./verify.sh /dev/sdX                              # confirm before shipping
```

`install.sh` wipes `/dev/sdX` completely after a typed `yes` confirmation. Both
scripts refuse a disk that has mounted filesystems.

## Notes

- The local account `Admin` is created with the placeholder password `ChangeMe123!`.
  Change it after the first real login.
- That plaintext password lives in `unattend.xml` and is committed to this repo's
  git history. Do not push this repo anywhere public without rewriting history first.
- If `verify.sh` shows "no bootable device", the install has not necessarily failed.
  It boots from a blank OVMF varstore with no NVRAM boot entry, so it relies on the
  UEFI removable fallback `\EFI\Boot\BOOTX64.EFI`, which Windows does not always
  create. Mount the ESP and copy `\EFI\Microsoft\Boot\bootmgfw.efi` to that path —
  no reinstall needed.
