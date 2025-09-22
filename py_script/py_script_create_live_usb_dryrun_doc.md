# `create_live_usb_dryrun.py` – Live USB Creation Helper (Dry-Run + Safety)

This script is part of the [`linux-setup`](https://github.com/yourname/linux-setup) project and helps you prepare a
bootable Linux Live USB using the `dd` command in a safe and user-friendly way.

## 🚀 Features

- Checks that your ISO file exists
- Lists all available block devices using `lsblk`
- Automatically detects likely USB devices (by size)
- Warns if a **partition** (e.g., `sde1`) is selected instead of a **whole device** (e.g., `sde`)
- Suggests the correct `dd` command, but only runs it if you confirm
- Works entirely in the terminal (CLI-only, no GUI required)

## 📦 Requirements

- Python 3
- Linux system (tested with `lsblk`)
- Superuser rights (only required if you confirm running the `dd` command)

## 📁 Script Location

```text
py_script/create_live_usb_dryrun.py
```

## ⚙️ Usage

```bash
python3 create_live_usb_dryrun.py /path/to/your.iso [optional_device_name]
```

### Example:

```bash
python3 create_live_usb_dryrun.py ~/Downloads/manjaro.iso sde
```

### Example with partition (auto-corrected):

```bash
python3 create_live_usb_dryrun.py ~/Downloads/ubuntu.iso sde1
```

The script will detect that `sde1` is a partition and automatically switch to `sde`.

## 🧪 What it does

1. Verifies that the ISO file exists.
2. Shows a list of available devices (`lsblk`).
3. If no device is specified, it tries to auto-detect a USB stick based on size (8–64 GB).
4. Generates the proper `dd` command:

   ```bash
   sudo dd if='/path/to/your.iso' of='/dev/sdx' bs=4M status=progress && sync
   ```

5. Asks for confirmation before executing anything.

## 🛡️ Safety Tips

- Never run `dd` on your system drive (e.g. `/dev/sda`, `/dev/nvme0n1`)
- Always verify the target USB device with `lsblk` before confirming
- This tool **does not** format or mount devices — it assumes you're writing an ISO image to the raw device

## 🧠 Optional Enhancements

- Add `fzf` for interactive device selection
- Add checksum verification for ISO files
- Create a GUI wrapper using `Tkinter` or `zenity` (future roadmap)

## 📜 License

This script is part of the `linux-setup` project  
Licensed under MIT License (or adapt to your project license)


---

## 🔍 How to Verify the USB Stick After Writing

After using `dd`, your USB stick might appear empty in your file manager — this is normal for ISO-based live systems.
Here's how to verify everything was written correctly:

### 🧪 Check if the ISO was written correctly:

```bash
sudo file -s /dev/sdX
```

Replace `sdX` with your actual device name (e.g. `sde`).  
You should see output like:

```
/dev/sde: DOS/MBR boot sector; partition 1 ...
```

### 🗂 Check file system and partitions:

```bash
lsblk -f
```

Look for `iso9660` or another read-only bootable file system under your USB device.

### 🔌 Mount manually (if needed):

```bash
sudo mount /dev/sdX1 /mnt
ls /mnt
```

If the mount succeeds, you'll see the ISO file contents.

### 💻 Test booting with QEMU (optional):

```bash
qemu-system-x86_64 -enable-kvm -m 2048 -boot d -cdrom /dev/sdX
```

Replace `sdX` with your USB device name (like `sde`).  
This allows you to simulate booting without restarting your system.

---

