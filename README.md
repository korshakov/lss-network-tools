# LSS macOS Network Tools

## Overview
LSS macOS Network Tools is a menu-driven CLI utility for professional network engineers performing on-site audits on macOS. It combines common diagnostics workflows (discovery, gateway scanning, DHCP review, topology summarization, and reporting) into one script.

## Features
- Automatic dependency check on every run (`brew`, `nmap`, `arp-scan`, `speedtest-cli`)
- Optional automatic installation of missing dependencies through Homebrew
- Automatic GitHub release check with in-place update option
- Interface selection that filters out non-usable interfaces (Bluetooth PAN, Thunderbolt Bridge, AWDL, P2P)
- Device discovery with vendor detection from nmap MAC OUI mapping
- Gateway port scan and fingerprint scan
- Rogue DHCP detection
- Web admin interface discovery
- Remote access service detection
- Internet speed testing
- Network topology summary with vendor-based category breakdown
- Session logging and Desktop report export

## Requirements
- macOS
- Homebrew
- `nmap`
- `arp-scan`
- `speedtest-cli`

## Installation
### Clone and run from source
```bash
git clone https://github.com/korshakov/lss-macos-network-tools.git
cd lss-macos-network-tools
chmod +x lss-macos-network-tools
./lss-macos-network-tools
```

### Install as a system command
```bash
sudo ./install.sh
```

Then run:
```bash
lss
```

### Homebrew installation
You can install via a custom tap/formula path in this repository:
```bash
brew install ./homebrew-tools/Formula/lss-macos-network-tools.rb
```

## Usage
Run from repository:
```bash
./lss-macos-network-tools
```

Show version:
```bash
./lss-macos-network-tools --version
```

Run installed command:
```bash
lss
```

## Export reports
On exit, the script asks:

`Export session report to Desktop? (y/n)`

If accepted, a report is created at:

`~/Desktop/LSS-NetInfo-Export-YYYY-MM-DD_HH-MM-SS.txt`

The report contains:
- Report title
- Generated timestamp
- Selected interface
- Detected gateway
- Full logged session output

## Updating
The script checks for the latest GitHub release at startup using:

`https://api.github.com/repos/korshakov/lss-macos-network-tools/releases/latest`

If a newer version is available, it prompts to download and install the update, then restarts automatically.

## License
MIT License (Copyright © 2026 LS Solutions).

Use this tool only on networks you own or have permission to audit.
