# 💻 linux-setup

A **modular, open-source Linux setup and hardening toolkit**, combining dotfiles, automation scripts, and now a full 
**Security Dashboard (Qt GUI)** for proactive defense.  
Works seamlessly on **Debian, Ubuntu, Arch, Manjaro**, and derivatives.

> 🛡️ One command to secure your Linux system: provision, audit, and monitor automatically.

---

## 📦 Project Structure

```text
linux-setup/
├── dotfiles/                # Modular shell configs (.aliasesrc, .aptrc, etc.)
├── scripts/                 # Core shell & provisioning scripts
│   ├── provision-security.sh      # One-command security setup
│   ├── verify-security-json.sh    # Audit-only check
│   ├── linux-setup-ui.sh          # Interactive TUI
│   └── install-*.sh               # Optional installers (git, gimp, etc.)
├── gui/                     # Qt GUI Dashboard (PySide6 + qasync)
│   ├── app.py               # Entry point (linux-setup-gui)
│   ├── main_window.py       # UI class
│   └── backend_client.py    # D-Bus connector
├── security/                # Config files & systemd units
│   ├── config/              # Falco, auditd, fail2ban configs
│   └── systemd/             # security-check.timer & service
├── pyproject.toml           # Poetry config & dependencies
├── bootstrap.sh             # Recreate repo structure
├── install.sh               # Dotfile / environment setup
└── LICENSE
````

---

## 🚀 Quick Start (Recommended)

### 1️⃣ Install Git & Curl

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y git curl
# Manjaro / Arch
sudo pacman -Sy --noconfirm git curl
```

### 2️⃣ Clone the Repository

```bash
git clone https://github.com/astrapi69/linux-setup.git ~/linux-setup
cd ~/linux-setup
```

### 3️⃣ Provision the Security Stack

```bash
sudo bash scripts/provision-security.sh
```

This command installs and configures:

* **Firewall (UFW)**: default deny incoming
* **Fail2ban**: SSH brute-force protection
* **Lynis, RKHunter, Chkrootkit**: system audit and malware scan
* **Falco**: runtime anomaly detection
* **auditd**: kernel-level auditing
* **systemd timers**: daily verification @07:00
* **Markdown report** → `~/linux-setup-report/latest.md`

---

## 🖥️ GUI Dashboard (Qt)

Run the cross-platform **Security Dashboard** to view findings and apply fixes.

```bash
poetry install --with gui
poetry run linux-setup-gui
```

Features:

* 🔍 View audit results
* 🛠️ Apply safe fixes
* 📄 Open the latest Markdown report
* 🕓 Auto-refresh on new audits

> Requires **Python ≥3.9, <3.14** and Qt runtime (`PySide6`, `dbus-next`, `qasync`).

---

## 💡 Text-Based Interface (TUI)

For SSH or server environments:

```bash
bash scripts/linux-setup-ui.sh
```

Perform audits, install missing tools, manage services, and validate Falco rules — all without a GUI.

---

## ⚙️ Apply Shell Setup (Optional)

```bash
bash install.sh
source ~/.bashrc   # or source ~/.zshrc
```

This merges modular dotfiles and sets up convenient aliases for cleanup and maintenance.

---

## 🔄 Cleanup Utilities

After setup, you can use:

```bash
cleanup             # Runs apt/pacman cleanup and updates
cleanupThumbnails   # Clears cached thumbnails
```

---

## 🧩 Optional Software Installers

Run any installer individually:

```bash
bash ./scripts/install-git.sh
bash ./scripts/install-chromium.sh
bash ./scripts/install-gimp.sh
```

Each script is standalone, so you can choose what you need without bloat.

---

## 🪪 Live USB Creation (Advanced)

Safely create bootable Linux USB drives using:

```text
py_script/py_script_create_live_usb_dryrun_doc.md
```

Includes validation, device detection, and dry-run safety before writing with `dd`.

---

## 🧑‍💻 Development

Build or extend the GUI easily using [Poetry](https://python-poetry.org/).

```bash
poetry install --with gui
poetry run linux-setup-gui
```

See the [Development Wiki](https://github.com/astrapi69/linux-setup/wiki/Development)
for guidelines, dependency groups, and code structure.

---

## 🧠 Related Documentation

Explore more in the [linux-setup Wiki](https://github.com/astrapi69/linux-setup/wiki):

* [⚡ Quick Start](https://github.com/astrapi69/linux-setup/wiki/Quick-Start)
* [🔒 Security Verification, Falco & TUI](https://github.com/astrapi69/linux-setup/wiki/Security-Verification)
* [🖥️ GUI Dashboard (Qt)](https://github.com/astrapi69/linux-setup/wiki/GUI-Dashboard-%28Qt%29)
* [❓ FAQ & Troubleshooting](https://github.com/astrapi69/linux-setup/wiki/FAQ-&-Troubleshooting)
* [🧑‍💻 Development](https://github.com/astrapi69/linux-setup/wiki/Development)

---

## 📄 License

Licensed under the **MIT License**.
See [`LICENSE`](./LICENSE) for details.

---
