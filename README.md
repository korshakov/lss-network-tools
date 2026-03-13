# LSS Network Tools

Run the toolkit directly from the repository root:

```bash
./lss-network-tools.sh
```

The launcher detects your OS and runs the correct scanner:

- `macOS/lss-network-tools-macos.sh`
- `linux/lss-network-tools-linux.sh`

No installation to `/usr/local/bin` or other system directories is required.

## Repository Structure

```text
lss-network-tools/
├── lss-network-tools.sh
├── analyzer.py
├── README.md
├── macOS/
│   └── lss-network-tools-macos.sh
├── linux/
│   └── lss-network-tools-linux.sh
└── analyzer-data/
```

## Requirements

The scanner scripts can check and install missing dependencies when run.

Typical dependencies include:

- `nmap`
- `arp-scan`
- `speedtest-cli`

## Notes

Scan output is written to `analyzer-data/` in the repository root.
