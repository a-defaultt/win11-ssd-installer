# win11-ssd-installer

Installs Windows 11 Pro fully unattended onto a bare external SSD (USB enclosure),
using QEMU/KVM with UEFI Secure Boot firmware and an emulated TPM 2.0, so the
resulting disk boots on real hardware like a normal internal Windows install — not
a "Windows To Go" portable image. The install never gets network access, and a
local `Administrators`-group account is created automatically during OOBE.

**Start here:** [`HOWTO.md`](HOWTO.md) — step-by-step run instructions, including
a hardware caveat (bus power) that will otherwise look like a driver bug.

## Prerequisites

- Packages: `qemu-system-x86`, `ovmf`, `swtpm`, `swtpm-tools`, `gdisk`, `genisoimage`, `socat`.
- A VNC client if you want to watch the install (e.g. `tigervnc-viewer` or Remmina).
- Root: `install.sh` and `verify.sh` write raw to the block device and refuse to run without it.
- A Windows 11 ISO (the image index in `unattend.xml` is pinned to Windows 11 Pro on
  the specific ISO this was built against — re-check the image list before reusing
  this answer file against a different ISO).
- `verify.sh` needs a graphical session or a VNC client; both scripts open a QEMU
  VNC server on `127.0.0.1:5901` rather than a local window.

## Usage

```
sudo ./install.sh /dev/sdX /path/to/windows.iso   # ~20-30 min with KVM
sudo ./verify.sh /dev/sdX                         # confirm before shipping
```

`install.sh` wipes `/dev/sdX` completely after a typed `yes` confirmation. Both
scripts refuse a disk that has mounted filesystems or isn't USB-attached.

Full details, troubleshooting, and the reasoning behind the design are in
[`HOWTO.md`](HOWTO.md) and the completion report referenced there.

## Notes

- The local account `Admin` is created with the placeholder password
  `ChangeMe123!` from `unattend.xml`. **Set your own password in `unattend.xml`
  before running `install.sh`**, and change it again after the first real login.
- If `verify.sh` shows "no bootable device", the install has not necessarily failed.
  It boots from a blank OVMF varstore with no NVRAM boot entry, so it relies on the
  UEFI removable fallback `\EFI\Boot\BOOTX64.EFI`, which Windows does not always
  create. Mount the ESP and copy `\EFI\Microsoft\Boot\bootmgfw.efi` to that path —
  no reinstall needed.
