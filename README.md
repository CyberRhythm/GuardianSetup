# 🛡️ Server Management & Security Script

> A personal Bash script for setting up, updating, and hardening Linux servers.

> 🚧 **This project is currently under active development.**
> Features, security modules, compatibility, and overall functionality are continuously being improved.

---

## 📋 Table of Contents

* [Features](#features)
* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [Modules & Menus](#modules--menus)
* [Port Whitelist](#port-whitelist)
* [File Structure](#file-structure)
* [Security Notes](#security-notes)
* [Distribution Support](#distribution-support)
* [Logs](#logs)
* [Contributing](#contributing)
* [License](#license)

---

## ✨ Features

| Feature               | Description                                                       |
| --------------------- | ----------------------------------------------------------------- |
| 🔄 Full System Update | Automatically updates all packages and the distribution           |
| 🔍 Server Scanner     | Detects installed services and active ports                       |
| 🔌 Port Whitelist     | Scans active ports and automatically creates a whitelist          |
| 🔥 Smart Firewall     | Configures UFW based on active ports and the whitelist            |
| 🛡️ SSH Hardening     | Disables root login and limits authentication attempts            |
| 🚫 Fail2Ban           | Automatically installs and configures Fail2Ban to block attacks   |
| 🦠 ClamAV             | Antivirus with automatic daily scanning                           |
| 📊 Auditd             | Security logging for sensitive system changes                     |
| ⚙️ Service Management | Enable or disable supported services with dedicated controls      |
| 🧱 Kernel Hardening   | Security-focused `sysctl` configuration for networking and memory |

---

## 🔧 Requirements

* **OS:** Linux (Ubuntu/Debian/CentOS/RHEL/Rocky/AlmaLinux/Fedora/Arch)
* **Access:** Root or sudo privileges
* **Shell:** Bash 4.0+
* **Internet:** Required for installing packages

---

## 🚀 Installation

### Method 1: Clone the Repository

```bash
git clone https://github.com/GuardianSetup/server-setup.git
cd server-setup
chmod +x setup.sh
sudo ./setup.sh
```

### Method 2: Direct Download

```bash
curl -O https://raw.githubusercontent.com/GuardianSetup/server-setup/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### Running After a Server Reboot

If you want to make the script easier to run after every reboot, you can optionally create an alias:

```bash
echo "alias server-setup='sudo /path/to/server-setup/setup.sh'" >> ~/.bashrc
source ~/.bashrc
```

---

## 📖 Usage

Run the script with root or sudo privileges:

```bash
sudo ./setup.sh
```

After launching, the main menu will be displayed:

```text
══════ Main Menu ══════

  1) 🔄  Full Run (Update + Security)
  2) 📦  System Update
  3) 🛡️   Security Configuration
  4) 🔍  Server Scan (What's Installed?)
  5) 🔥  Firewall Management (UFW)
  6) ✅  Enable Services
  7) ❌  Disable Services
  8) 📋  Show Server Status
  9) 📝  View Logs
  0) 🚪  Exit
```

---

## 📦 Modules & Menus

### 1. Full Run

Runs all major steps sequentially:

**System Update → Security Hardening → Smart Firewall Configuration**

This is particularly useful for performing a complete server setup after a fresh installation or reboot.

---

### 2. System Update

The system update module performs:

* Package list updates
* Upgrade of all installed packages
* `dist-upgrade`
* Removal of unnecessary packages

**Supported package managers:**

* Ubuntu/Debian → `apt`
* CentOS/RHEL/Rocky → `yum` / `dnf`
* Arch → `pacman`

---

### 3. Security Configuration

| Option            | Description                                                                |
| ----------------- | -------------------------------------------------------------------------- |
| SSH Hardening     | Disables root login, limits attempts to 3, and configures timeout settings |
| Fail2Ban          | Automatically blocks suspicious IP addresses                               |
| ClamAV            | Antivirus with daily scans of `/home` and `/tmp`                           |
| Auditd            | Logs changes to sudoers, SSH, cron, and user accounts                      |
| Automatic Updates | Automatically installs security patches                                    |
| Kernel Hardening  | Enables ASLR and SYN cookies and disables ICMP redirects                   |

---

### 4. Server Scanner 🔍

The server scanner automatically detects what is installed and active on the server.

It checks:

* **Installed Services:** Nginx, Apache, MySQL, PostgreSQL, MongoDB, Redis, Docker, and more
* **Active Ports:** Full scan using `ss` or `netstat`
* **Whitelist Status:** Compares active ports against the configured whitelist
* **Disk & RAM Usage**
* **High-Resource Processes**

---

### 5. Firewall Management (UFW)

```text
1) Configure Smart Firewall   ← Scan Ports + Whitelist → UFW
2) Open Port                  ← Add to UFW + Whitelist
3) Close Port                 ← Remove from UFW + Whitelist
4) Show UFW Status
5) Enable UFW
6) Disable UFW
7) Manage Whitelist
```

> ⚠️ **Important:** Port `22` (SSH) should always remain in the whitelist unless you have another confirmed way to access the server.

---

### 6 & 7. Enable / Disable Services

Every service that can be enabled has a corresponding disable option.

| Service       | Enable             | Disable            |
| ------------- | ------------------ | ------------------ |
| Nginx         | Menu 6 → Option 1  | Menu 7 → Option 1  |
| Apache        | Menu 6 → Option 2  | Menu 7 → Option 2  |
| MySQL/MariaDB | Menu 6 → Option 3  | Menu 7 → Option 3  |
| PostgreSQL    | Menu 6 → Option 4  | Menu 7 → Option 4  |
| MongoDB       | Menu 6 → Option 5  | Menu 7 → Option 5  |
| Redis         | Menu 6 → Option 6  | Menu 7 → Option 6  |
| RabbitMQ      | Menu 6 → Option 7  | Menu 7 → Option 7  |
| Docker        | Menu 6 → Option 8  | Menu 7 → Option 8  |
| Fail2Ban      | Menu 6 → Option 9  | Menu 7 → Option 9  |
| UFW           | Menu 6 → Option 10 | Menu 7 → Option 10 |
| Auditd        | Menu 6 → Option 13 | Menu 7 → Option 12 |
| ClamAV        | Menu 6 → Option 14 | Menu 7 → Option 13 |

> ⚠️ **SSH:** Disabling SSH requires explicit `YES` confirmation to prevent accidental loss of server access.

---

## 🔌 Port Whitelist

The port whitelist is stored in:

```text
config/port_whitelist.conf
```

Example:

```text
# SSH - Required (Never Remove!)
22

# HTTP / HTTPS
80
443
```

### Whitelist Logic

```text
Scan Active Ports
        ↓
Compare Against Whitelist
        ↓
    ┌───────────────────┬────────────────────┐
    │ In Whitelist      │ Not In Whitelist   │
    │      ✅ Approved  │ ⚠️ Review Required │
    └───────────────────┴────────────────────┘
        ↓
Add to Whitelist or Manage Manually
```

---

## 📁 File Structure

```text
server-setup/
├── setup.sh                    # Main script
├── README.md                   # Documentation
├── config/
│   ├── port_whitelist.conf     # Port whitelist
│   └── state.conf              # Configuration state (auto-generated)
├── logs/
│   └── setup_YYYYMMDD_HH.log  # Execution logs
└── .github/
    └── workflows/
        └── lint.yml            # Automated ShellCheck validation
```

---

## 🔒 Important Security Notes

### ⚠️ Read Before Running

1. **Do not close SSH accidentally!**
   Do not remove port `22` from the whitelist unless you have an alternative confirmed access method.

2. **SSH Configuration Backup**
   The script automatically creates a backup:

   ```text
   /etc/ssh/sshd_config.backup_DATE
   ```

3. **Root Login**
   SSH hardening disables direct root login. Make sure you have a sudo-enabled user before applying this configuration.

4. **Smart Firewall**
   Before enabling UFW, make sure the SSH port is included in the whitelist.

5. **Test Before Production**
   Always test the script on a non-production server before deploying it to a production environment.

---

## 🐧 Distribution Support

| Distribution    | Updates | Packages | Tested |
| --------------- | ------- | -------- | ------ |
| Ubuntu 20.04+   | ✅       | ✅        | ✅      |
| Debian 11+      | ✅       | ✅        | ✅      |
| CentOS 7/8      | ✅       | ✅        | ✅      |
| Rocky Linux 8/9 | ✅       | ✅        | ✅      |
| AlmaLinux 8/9   | ✅       | ✅        | ✅      |
| Fedora 36+      | ✅       | ✅        | ⚠️     |
| Arch Linux      | ✅       | ⚠️       | ⚠️     |

> 🚧 **Compatibility is still being improved as the project is under active development.**

---

## 📝 Logs

Each execution creates a separate log file inside the `logs/` directory:

```text
logs/setup_20250525_143022.log
```

### View the Latest Log

```bash
tail -f logs/$(ls -t logs/ | head -1)
```

---

## 🤝 Contributing

This is currently a personal project, but suggestions and contributions are welcome.

1. Fork the repository
2. Create a new branch:

```bash
git checkout -b feature/my-feature
```

3. Commit your changes:

```bash
git commit -m "Add: my feature"
```

4. Push your branch:

```bash
git push origin feature/my-feature
```

5. Open a Pull Request

---

## 🚧 Project Status

**Active Development**

This project is currently under active development. New features, improvements, security enhancements, bug fixes, and additional Linux distribution support may be added over time.

The current implementation should be considered a work in progress. Always review the script and test it in a safe environment before using it on production servers.

---

## 📜 License

**MIT License** — Free to use with attribution.
