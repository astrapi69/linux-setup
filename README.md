# 💻 linux-setup

A portable, modular, and open-source Linux setup toolkit :-: including dotfiles, automation scripts, and system cleanup
tools for Debian, Ubuntu, Arch, and more. Perfect for quickly bootstrapping your development or workstation environment.

---

## 📦 Structure

```
linux-setup/
├── dotfiles/              # Modular dotfiles (.aliasesrc, .aptrc, etc.)
├── scripts/               # Core shell scripts (init, profile generation, helpers)
├── etc/cron.daily/        # Optional system-level cron jobs
├── install.sh             # Main installation script (detects Bash/Zsh)
├── bootstrap.sh           # Script to generate this folder structure
├── README.md              # This documentation
└── LICENSE                # License file
```

---

## 🚀 Quick Setup

### 1. Install Git and Curl (if not already installed)

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install -y git curl

# Manjaro/Arch
sudo pacman -Sy --noconfirm git curl
```

### 2. Clone this Repository

```bash
git clone https://github.com/YOUR_USERNAME/linux-setup.git ~/linux-setup
cd ~/linux-setup
```

> Replace `YOUR_USERNAME` with your GitHub username.

### 3. Run the Installation Script

```bash
cd scripts/../resources   # or wherever install.sh is located
bash install.sh
```

This will:

- Detect your shell (bash or zsh)
- Generate a `.profile` or `.zshrc` by merging dotfiles
- Ensure it's sourced in `.bashrc` or `.zshrc`

### 4. Apply the New Configuration

```bash
source ~/.bashrc   # or source ~/.zshrc
```

---

## 🔄 Cleanup Utilities

The setup includes functions you can use after installing:

```bash
cleanup             # Runs OS-specific cleanup (apt, pacman, etc.)
cleanupThumbnails   # Removes thumbnail cache from ~/.cache/thumbnails
```

---

## 🧪 Testing the Structure (Optional)

You can recreate this structure from scratch using:

```bash
bash bootstrap.sh
```

This will create all necessary folders and files if missing.

---

## 📄 License

This project is licensed under the MIT License. See [`LICENSE`](./LICENSE) for details.

---

## 🧩 Optional Software Installers

This repository includes a collection of optional installation scripts located in the `scripts/` directory. These
scripts install useful software such as:

- Git
- Chromium
- Gnome Sushi
- GIMP
- Node.js
- Audacious
- Keepass2
- Calibre
- and more...

### 🔧 How to use

After cloning this repository and running the main setup, you can run any optional install script manually like so:

```bash
bash ./scripts/install-git.sh
bash ./scripts/install-chromium.sh
bash ./scripts/install-gnome-sushi.sh
```

These scripts are safe to run individually, so you can pick and choose what you need.

---

## 🪪 Live USB Creation (Advanced Utility)

If you want to safely create a bootable Linux Live USB using the `dd` command, check out the helper script and
documentation in:

```text
py_script/py_script_create_live_usb_dryrun_doc.md
