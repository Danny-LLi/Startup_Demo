# 🚀 Startup

<p align="center">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux"/>
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/Privacy-Focused-blueviolet?style=for-the-badge" alt="Privacy"/>
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <em>Intelligent Linux automation for privacy-conscious power users</em>
</p>

---

> **⚠️ NOTE:** This is a **simplified demonstration version** of the full Startup suite. The complete system includes advanced network monitoring, system reconnaissance capabilities, and additional privacy-hardening features that are not included in this public repository for security considerations. This demo focuses on the core automation and backup functionality.

---

## 📋 Overview

**Startup** is an intelligent service orchestration tool that automates essential privacy and backup workflows on Linux systems. With a single click, it manages VPN connections, creates encrypted backups, and monitors critical system processes—perfect for users who value privacy, automation, and peace of mind.

## ✨ Key Features (Demo Version)

### 🔐 Privacy & Security
- **ProtonVPN Integration** - Seamless VPN connection with auto-start and minimized tray icon
- **Encrypted Backups** - GPG-encrypted, automated backups of your Obsidian Vault to Google Drive
- **Secure Credential Storage** - Uses GNOME Keyring for safe passphrase management

### 📊 System Monitoring
- **Network Process Tracker** - Real-time monitoring of all internet-connected processes with detailed information:
  - Process IDs (PIDs) and port numbers
  - Connection states (LISTEN, ESTABLISHED, SYN_SENT)
  - Full command paths and executable details
  - User ownership information

### 🤖 Automation
- **One-Click Orchestration** - Start/stop all services through an intuitive Zenity dialog
- **Intelligent Service Management** - Graceful startup/shutdown with proper dependency handling
- **Comprehensive Logging** - Detailed logs with automatic rotation (10MB threshold)
- **Background Processing** - Non-blocking uploads and operations

### 🔒 Backup System
- **Automatic Encryption** - AES256 cipher for your sensitive data
- **Integrity Verification** - Validates archives before upload
- **Cloud Sync** - Seamless integration with Google Drive via rclone
- **Network-Aware** - Intelligently handles connectivity issues

## 🎬 Demo

<p align="center">
  <video src="https://github.com/user-attachments/assets/f6ffc935-cde2-496f-b58e-5c5d0da3ad76"
         width="600"
         controls
         poster="assets/demo-cover.jpg"
         style="border-radius:12px; box-shadow:0 0 12px rgba(0,0,0,0.3);">
      Your browser does not support the video tag.
  </video>
</p>

## 🔍 What's Different in the Full Version?

*Some features are omitted from the public demo for security and privacy considerations.*

## 🛠️ Installation

### Prerequisites

```bash
# Required packages
sudo apt install zenity notify-send gpg tar rclone \
                 gnome-keyring lsof network-manager protonvpn-app
```

### Setup Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Danny-LLi/Startup_Demo.git
   cd startup
   ```

2. **Copy scripts to system directory:**
   ```bash
   sudo mkdir -p /usr/bin/mine/startup
   sudo cp net-processes.sh /usr/bin/mine/
   sudo cp startup.sh /usr/bin/mine/startup/
   sudo chmod +x /usr/bin/mine/net-processes.sh
   sudo chmod +x /usr/bin/mine/startup/startup.sh
   ```

3. **Set up desktop launcher:**
   ```bash
   cp mine_startup.desktop ~/.local/share/applications/
   # Edit the file and replace USERNAME with your actual username
   sed -i "s/USERNAME/$USER/g" ~/.local/share/applications/mine_startup.desktop
   chmod +x ~/.local/share/applications/mine_startup.desktop
   ```

4. **Configure sudo permissions** (for Bluetooth control):
   ```bash
   sudo visudo
   # Add this line (replace USERNAME with your username):
   USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl start bluetooth
   ```

5. **Store GPG passphrase in keyring:**
   ```bash
   secret-tool store --label="Startup GPG Key" service startup_key passphrase startup_passphrase
   # Enter your GPG passphrase when prompted
   ```

6. **Configure rclone for Google Drive:**
   ```bash
   rclone config
   # Follow prompts to set up 'gdrive' remote
   ```

7. **Install GNOME AppIndicator extension** (for ProtonVPN tray icon):
   ```bash
   gnome-extensions install appindicatorsupport@rgcjonas.gmail.com
   gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
   ```

## 📖 Usage

### Quick Start

Launch from your applications menu or run:
```bash
/usr/bin/mine/startup/startup.sh
```

The interactive dialog will show current service status and allow you to start/stop everything with one click.

### Network Process Monitor

**List all internet-connected processes:**
```bash
/usr/bin/mine/net-processes.sh
```

**Show detailed info for specific PIDs:**
```bash
/usr/bin/mine/net-processes.sh -p 1234,5678
```

**Output format:**
```
┌─ Port: 443 PID: 12345 State: ESTABLISHED
└─ ➤ /usr/bin/firefox

┌─ Port: 22 PID: 678 State: LISTEN
└─ ➤ /usr/sbin/sshd
```

### Service Management

**Start Services:** Opens dialog → "Yes, Start Services"
- Enables Bluetooth
- Connects to ProtonVPN
- Backs up & uploads Obsidian Vault to Google Drive

**Stop Services:** Opens dialog → "Yes, Stop Services"  
- Disconnects ProtonVPN
- *Note: Bluetooth remains active*

## 📁 Project Structure

```
startup/
├── startup.sh                  # Main orchestration script (simplified demo)
├── net-processes.sh            # Network process monitor
├── mine_startup.desktop        # Desktop launcher
└── README.md                   # This file
```

## 🔧 Configuration

### Customizing Backup Settings

Edit `startup.sh` variables:
```bash
RCLONE_REMOTE="gdrive"                    # Your rclone remote name
BACKUP_PATH="$HOME/Documents"             # Directory containing vault
GNOME_LOAD_DELAY=5                        # Seconds to wait for GNOME
VPN_CONNECTION_TIMEOUT=30                 # Max VPN connection wait time
BACKUP_UPLOAD_DELAY=60                    # Delay before upload starts
```

### Changing Backup Directory

By default, the script backs up `$HOME/Documents/Obsidian Vault`. To change this:
```bash
# Edit startup.sh
BACKUP_PATH="/path/to/your/backup/folder"
```

Then modify the `start_obsidian_backup()` function to target your desired directory.

## 🪵 Logging

Logs are stored in `~/.local/share/startup-services/`:
- `startup.log` - Main service orchestration log (auto-rotates at 10MB)
- `protonvpn.log` - VPN connection details

View real-time logs:
```bash
tail -f ~/.local/share/startup-services/startup.log
```

## 🔒 Security Considerations

- **GPG Passphrase:** Stored in GNOME Keyring (encrypted at rest)
- **Sudo Permissions:** Limited to Bluetooth service only
- **VPN:** ProtonVPN recommended for trusted privacy protection
- **Backup Encryption:** AES256 cipher for all archived data
- **Credential Management:** No plaintext passwords in scripts

## 🐛 Troubleshooting

### ProtonVPN won't start
```bash
# Ensure AppIndicator extension is installed
gnome-extensions list | grep appindicator

# Verify ProtonVPN config exists
ls ~/.config/Proton/VPN/app-config.json

# Test ProtonVPN manually
protonvpn-app
```

### Backup upload fails
```bash
# Test rclone connection
rclone about gdrive:

# Reconnect if authentication expired
rclone config reconnect gdrive:

# Check network connectivity
ping -c 3 google.com
```

### Network process monitor shows no output
```bash
# Verify lsof is installed
which lsof

# Check if processes are using network
sudo lsof -i -nP

# Verify script permissions
ls -la /usr/bin/mine/net-processes.sh
```

### Bluetooth fails to start
```bash
# Check Bluetooth service status
systemctl status bluetooth

# Verify sudo permissions
sudo -l | grep bluetooth

# Start manually to see errors
sudo systemctl start bluetooth
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for:
- Bug fixes
- Feature enhancements
- Documentation improvements
- Security improvements

## ⚡ Extending the System

This demo version is designed to be a foundation. You can extend it by:

- Adding custom backup targets beyond Obsidian Vault
- Integrating additional VPN providers
- Creating custom monitoring scripts
- Adding email/webhook notifications for backup completion

The modular design makes it easy to add your own automation workflows.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **ProtonVPN** - Privacy-focused VPN service
- **rclone** - Universal cloud storage synchronization
- **GNOME Project** - Desktop environment and keyring integration

## 💡 Why a Demo Version?

This simplified version demonstrates the core automation concepts while keeping the codebase accessible and security-focused. The full system includes additional capabilities that, while powerful, require careful configuration and understanding of network security principles.

By starting with this demo, you can:
- Learn the automation patterns
- Understand the logging and error handling
- Customize the backup and VPN workflows
- Build your own extensions safely

---

<p align="center">
  Made with ❤️ for privacy-conscious Linux users<br>
  <em>Demo version - Core functionality showcase</em>
</p>
