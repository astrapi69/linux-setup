import os
import sys
import subprocess
from pathlib import Path
import re


def list_disks():
    print("🔍 Available disks (Linux):\n")
    subprocess.run(["lsblk", "-o", "NAME,SIZE,TYPE,MOUNTPOINT"], check=True)


def check_iso_file(iso_path):
    if not Path(iso_path).is_file():
        print(f"❌ ISO file not found: {iso_path}")
        sys.exit(1)
    print(f"✅ ISO file found: {iso_path}")


def normalize_device_name(name):
    """
    Ensures that device name is like 'sde' not 'sde1'
    """
    match = re.match(r"^([a-z]+[a-z]*)(\d*)$", name)
    if not match:
        print(f"❌ Invalid device name format: {name}")
        sys.exit(1)
    base = match.group(1)
    if match.group(2):  # It ends with a digit → it's a partition
        print(f"⚠️ You provided a partition ({name}). Using full device: {base}")
    return base


def suggest_dd_command(iso_path, usb_device_raw):
    device = normalize_device_name(usb_device_raw)
    dd_command = f"sudo dd if='{iso_path}' of='/dev/{device}' bs=4M status=progress && sync"

    print("\n🧪 Suggested `dd` command (not executed yet):\n")
    print(dd_command)

    confirm = input("\n❓ Do you want to proceed and run this command? [y/N]: ").strip().lower()
    if confirm == 'y':
        print("\n🚀 Running `dd`... This may take several minutes.")
        os.system(dd_command)
    else:
        print("❌ Aborted by user. No changes made.")


def detect_usb_device():
    print("🧠 Attempting to auto-detect USB stick (based on typical removable sizes)...")
    result = subprocess.run(["lsblk", "-o", "NAME,SIZE,TYPE,MOUNTPOINT"], capture_output=True, text=True)
    lines = result.stdout.splitlines()

    for line in lines:
        if "disk" in line and any(size in line for size in ["8G", "16G", "32G", "59G", "64G"]):
            name = line.strip().split()[0]
            return name
    return None


def main():
    if len(sys.argv) < 2:
        print("❗ Usage: python create_live_usb_dryrun.py /path/to/linux.iso [optional_device_name]")
        sys.exit(1)

    iso_path = sys.argv[1]
    device_arg = sys.argv[2] if len(sys.argv) >= 3 else None

    check_iso_file(iso_path)
    list_disks()

    usb_device = device_arg or detect_usb_device()

    if not usb_device:
        print("❌ Could not determine target USB device. Please rerun with device name.")
        sys.exit(1)

    suggest_dd_command(iso_path, usb_device)


if __name__ == "__main__":
    main()
