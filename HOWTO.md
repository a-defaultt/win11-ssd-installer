# How-To: Install Windows 11 on a Bare SSD via USB Enclosure

Wipes a bare SSD and installs a fully unattended, enterprise-compatible Windows 11 onto it — entirely from this Ubuntu machine, no need to boot off the target disk.

## Before You Start

1. **Plug the SSD enclosure into a powered USB hub or dock — not directly into the laptop.**
   This specific enclosure (Gembird, JMicron `152d:0581` bridge) browns out and resets under sustained write load when bus-powered directly off a laptop USB3 port (it draws ~896mA, right at the USB3 900mA/port limit). This is not optional — a direct connection *will* fail partway through the install with USB reset errors and "no disk found" in Windows Setup.

2. Sanity-check the connection before committing to a full install (takes ~15s):
   ```
   sudo dd if=/dev/zero of=/dev/sda bs=1M count=500 status=progress oflag=sync
   ```
   It should complete cleanly with no errors. In another terminal, `journalctl -k -f` should show no `usb ... reset` lines while it runs. If you see resets, try a different port on the dock/hub before proceeding.

3. Confirm the ISO path and which device is the target disk:
   ```
   lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINT
   ```
   Only ever target the enclosure's device (confirm via `TRAN=usb` and the model name) — never a device with a mountpoint under it.

## Run the Install

```
sudo ~/Documents/Claude-Projects/win11-ssd-installer/install.sh /dev/sdX /path/to/Win11.iso
```

- You'll be asked to type `yes` to confirm the wipe — this is destructive and irreversible.
- The script then runs fully headless. To watch progress, connect a VNC client (e.g. Remmina, or `vncviewer` from `tigervnc-viewer`) to `127.0.0.1:5901` — no password.
- No manual interaction needed: it auto-answers the "press any key to boot from CD" prompt, runs Setup unattended (fr-FR locale, Windows 11 Pro, no product key), reboots on its own mid-install, completes OOBE with an auto-created local `Admin` account, and shuts itself down — at which point the script exits cleanly on its own.
- Typical duration: 15–30 minutes depending on disk/USB speed.

## Verify

```
sudo ~/Documents/Claude-Projects/win11-ssd-installer/verify.sh /dev/sdX
```

Boots the disk directly (no install media). Watch via the same VNC address. You should land on a normal Windows 11 desktop or lock screen, logged in (or ready to log in) as `Admin`. If you instead see "No bootable device" or a UEFI shell, the install didn't complete — re-run `install.sh`.

## Credentials

- Username: `Admin` (local account, Administrators group)
- Password: `ChangeMe123!` by default (set in two places in `unattend.xml` — the
  `LocalAccount` and the matching `AutoLogon` block). **Edit both before running
  `install.sh`** to set your own password, and change it again after first real
  login. Whatever password ends up in `unattend.xml` when you run the script is
  stored in plaintext on disk and in this repo's history — don't commit a real
  password if the repo is public.

## If It Fails

- **USB resets / "no disk found" in Windows Setup:** almost certainly the power issue above — check the dock/hub connection first, don't assume it's a driver bug.
- **Stuck on "Press any key to boot..." / loops back to boot menu:** shouldn't happen with the current script (it auto-injects the keypress via the QEMU monitor), but if it does, check `socat` is installed (`command -v socat`).
- **Answer file not applied / Setup asks questions manually:** the answer-file ISO must contain `autounattend.xml` (capital-insensitive but must be that exact name) at its root — this is what `install.sh` builds automatically, don't rename it.

## Full write-up

See `docs/superpowers/reports/2026-09-14-win11-ssd-installer-completion-report.md` for the complete build history, defects found during development, and the full USB power-brownout diagnosis.
