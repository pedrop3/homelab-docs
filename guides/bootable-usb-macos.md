# Flashing disk images to a USB drive with `dd` on macOS

This guide shows how to write a bootable `.iso` or `.img` file to a USB drive from the macOS Terminal. It works for Debian, Ubuntu, Raspberry Pi OS, rescue tools and other Linux images. You don't need to install anything, because `dd` and `diskutil` come with macOS.

> [!WARNING]
> `dd` erases everything on the target disk and never asks for confirmation. If you use the wrong disk number, it will wipe the wrong drive. Always check the size first. The USB drive's number can change every time you plug it in.

## Contents

- [Before you start](#before-you-start)
- [Flash the image](#flash-the-image)
- [Verify the result](#verify-the-result)
- [Format the drive for normal use](#format-the-drive-for-normal-use)
- [Troubleshooting](#troubleshooting)
- [Quick reference](#quick-reference)

## Before you start

1. **Download the image from the project's official website.** Avoid third-party mirrors you don't trust.
2. **Move the image out of `Downloads`.** macOS privacy protection stops Terminal from reading `Downloads`, `Desktop` and `Documents`, and `sudo` can't get around it. In Finder, drag the image into your home folder (`~`). The commands in this guide expect it there.
3. **Check the checksum.** Run the command below and compare the result with the SHA256 published by the project (usually in a `SHA256SUMS` file). If they don't match, download the image again.

   ```bash
   shasum -a 256 $HOME/image.iso
   ```

4. **Back up the USB drive.** It must be larger than the image, and everything on it will be erased.

In every command, replace `image.iso` with your file name and `N` with your USB drive's disk number.

## Flash the image

1. **Find the USB drive.**

   ```bash
   diskutil list external physical
   ```

   This command lists only external disks, so you can't mix up the USB drive with the Mac's own disk. The output looks like this:

   ```text
   /dev/disk18 (external, physical):
      #:                       TYPE NAME                    SIZE       IDENTIFIER
      0:     FDisk_partition_scheme                        *31.5 GB    disk18
      1:             Windows_FAT_32 NO NAME                 31.5 GB    disk18s1
   ```

   Write down the number (`18` here), and check that the size matches your USB drive.

2. **Unmount the drive.**

   ```bash
   diskutil unmountDisk /dev/diskN
   ```

3. **Write the image.**

   ```bash
   sudo dd if=$HOME/image.iso of=/dev/rdiskN bs=4m
   ```

   - Your Mac password doesn't show while you type. That's normal.
   - Use `rdiskN`, with the `r`. It's the same disk, but raw access makes the write much faster.
   - The Terminal looks frozen while it writes. Press **Ctrl+T** to see progress.
   - It's done when you see a line like `... bytes transferred in ... secs`.

4. **Eject the drive.**

   ```bash
   diskutil eject /dev/diskN
   ```

   macOS may say *"The disk you attached was not readable by this computer."* That's normal, because macOS can't read Linux image formats. Click **Eject**.

> [!TIP]
> If you want to check the write, run the steps in [Verify the result](#verify-the-result) before step 4.

## Verify the result

The flash worked if the USB drive has the same SHA256 as the image.

1. **Compare the byte count.** The number in `bytes transferred` must equal the image size. To see the image size:

   ```bash
   stat -f %z $HOME/image.iso
   ```

2. **Read the drive back and hash it.** This takes about 1–3 minutes.

   ```bash
   sudo head -c $(stat -f %z $HOME/image.iso) /dev/rdiskN | shasum -a 256
   ```

   If the result matches the image's checksum, the copy is identical byte for byte.

If you already ejected the drive, plug it back in, click **Ignore** on the macOS warning, and check the disk number again with `diskutil list external physical`.

The real test is booting the target machine from the drive. If the installer menu appears, everything worked.

## Format the drive for normal use

To use the drive for regular files again, erase it with `diskutil eraseDisk`. ExFAT is the best default. This also wipes the drive, so check the disk number first.

| Format | Command | Works on | Limits |
| --- | --- | --- | --- |
| ExFAT (recommended) | `diskutil eraseDisk ExFAT USBDRIVE MBR /dev/diskN` | macOS, Windows, Linux | None in practice |
| FAT32 | `diskutil eraseDisk FAT32 USBDRIVE MBR /dev/diskN` | Almost everything, including TVs, car stereos and older devices | Files up to 4 GB; name in uppercase, max 11 characters |
| APFS | `diskutil eraseDisk APFS USBDrive GPT /dev/diskN` | macOS only | Windows and Linux can't read it |

`USBDRIVE` is the name Finder will show, so you can change it. If you get `Resource busy`, run `diskutil unmountDisk /dev/diskN` and try again.

## Troubleshooting

| What you see | Cause | Fix |
| --- | --- | --- |
| `Operation not permitted` on the image | macOS blocks Terminal from `Downloads`, `Desktop` and `Documents` | Move the image to `~`. Or allow Terminal under **System Settings → Privacy & Security → Files and Folders**, then reopen Terminal |
| `Resource busy` | The drive is still mounted | Run `diskutil unmountDisk /dev/diskN`, then write again |
| `Permission denied` | `sudo` is missing | Start the command with `sudo` |
| Terminal looks frozen | `dd` doesn't show progress by default | Wait, or press **Ctrl+T** |
| *"The disk you attached was not readable"* | macOS can't read the Linux image format | Normal. Click **Eject**, or **Ignore** if you still want to verify or format |
| Image is `.zip`, `.gz` or `.xz` | The image is compressed | Decompress it first with `unzip`, `gunzip` or `xz -d` (`xz` comes from Homebrew: `brew install xz`) |
| Windows ISO won't boot | Windows ISOs aren't built to be copied raw | Use Microsoft's official tool on a Windows PC |
| The PC won't boot from the drive | Boot menu key or boot order | Press the boot menu key for your brand (usually F12, F11, F9, F8 or Esc). If that fails, put USB first in the BIOS boot order or turn off Secure Boot |

## Quick reference

```bash
# 1. Find the USB drive (note N and check the size)
diskutil list external physical

# 2. Check the image (compare with the project's SHA256)
shasum -a 256 $HOME/image.iso

# 3. Unmount
diskutil unmountDisk /dev/diskN

# 4. Write (Ctrl+T shows progress)
sudo dd if=$HOME/image.iso of=/dev/rdiskN bs=4m

# 5. Verify (must match the SHA256 from step 2)
sudo head -c $(stat -f %z $HOME/image.iso) /dev/rdiskN | shasum -a 256

# 6. Eject
diskutil eject /dev/diskN

# Later: reuse as a normal USB drive
diskutil eraseDisk ExFAT USBDRIVE MBR /dev/diskN
```