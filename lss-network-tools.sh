#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Darwin)
        exec sudo "$SCRIPT_DIR/macOS/lss-network-tools-macos.sh"
        ;;
    Linux)
        exec sudo "$SCRIPT_DIR/linux/lss-network-tools-linux.sh"
        ;;
    *)
        echo "Unsupported operating system."
        exit 1
        ;;
esac
