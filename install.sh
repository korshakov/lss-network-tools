#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="lss-network-tools"
APP_SCRIPT="lss-network-tools.sh"
OS=""
APP_TARGET_DIR="${LSS_INSTALL_APP_DIR:-}"
DATA_TARGET_DIR="${LSS_INSTALL_DATA_DIR:-}"
WRAPPER_PATH="${LSS_INSTALL_WRAPPER_PATH:-/usr/local/bin/${APP_NAME}}"
BREW_USER=""

log() {
  echo "[install] $*"
}

fail() {
  echo "[install] ERROR: $*" >&2
  exit 1
}

detect_os() {
  case "$(uname -s)" in
    Darwin)
      OS="macos"
      APP_TARGET_DIR="${APP_TARGET_DIR:-/usr/local/share/${APP_NAME}}"
      DATA_TARGET_DIR="${DATA_TARGET_DIR:-$APP_TARGET_DIR}"
      ;;
    Linux)
      OS="linux"
      APP_TARGET_DIR="${APP_TARGET_DIR:-/usr/local/lib/${APP_NAME}}"
      DATA_TARGET_DIR="${DATA_TARGET_DIR:-/var/lib/${APP_NAME}}"
      ;;
    *)
      fail "Unsupported platform: $(uname -s)"
      ;;
  esac
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    fail "Run install.sh with sudo or as root."
  fi
}

detect_brew_user() {
  if [[ "$OS" == "macos" && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    BREW_USER="$SUDO_USER"
  fi
}

run_brew_as_user() {
  local command_string="$1"

  if [[ -z "$BREW_USER" ]]; then
    fail "Homebrew actions on macOS require running install.sh with sudo from a normal admin user."
  fi

  sudo -u "$BREW_USER" bash -lc "$command_string"
}

ensure_homebrew() {
  if [[ "$OS" != "macos" ]]; then
    return 0
  fi

  if sudo -u "$BREW_USER" bash -lc 'command -v brew >/dev/null 2>&1'; then
    return 0
  fi

  log "Homebrew not found. Installing Homebrew for ${BREW_USER}..."
  run_brew_as_user 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

  if ! sudo -u "$BREW_USER" bash -lc 'command -v brew >/dev/null 2>&1'; then
    fail "Homebrew installation failed."
  fi
}

brew_install_if_missing() {
  local command_name="$1"
  local formula="$2"

  if sudo -u "$BREW_USER" bash -lc "command -v $command_name >/dev/null 2>&1"; then
    log "[OK] $command_name"
    return 0
  fi

  log "Installing $formula for missing command: $command_name"
  run_brew_as_user "brew install $formula"
}

install_linux_dependencies() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y nmap jq iproute2 iputils-ping tcpdump net-tools speedtest-cli zip unzip
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y nmap jq iproute iputils tcpdump net-tools speedtest-cli zip unzip
    return 0
  fi

  fail "No supported Linux package manager found. Expected apt-get or dnf."
}

install_macos_dependencies() {
  detect_brew_user
  ensure_homebrew

  brew_install_if_missing nmap nmap
  brew_install_if_missing jq jq
  brew_install_if_missing speedtest-cli speedtest-cli
  brew_install_if_missing tcpdump tcpdump

  log "[OK] ipconfig"
  log "[OK] ifconfig"
  log "[OK] route"
  log "[OK] networksetup"
  log "[OK] ping"
  log "[OK] zip"
}

install_dependencies() {
  if [[ "${LSS_SKIP_DEPS:-0}" == "1" ]]; then
    log "Skipping dependency installation because LSS_SKIP_DEPS=1"
    return 0
  fi

  log "Installing required dependencies..."

  if [[ "$OS" == "macos" ]]; then
    install_macos_dependencies
  else
    install_linux_dependencies
  fi
}

prepare_target_directories() {
  mkdir -p "$APP_TARGET_DIR"

  if [[ "$OS" == "linux" ]]; then
    mkdir -p "$DATA_TARGET_DIR/output" "$DATA_TARGET_DIR/raw" "$DATA_TARGET_DIR/tmp"
  else
    mkdir -p "$APP_TARGET_DIR/output" "$APP_TARGET_DIR/raw" "$APP_TARGET_DIR/tmp"
  fi
}

deploy_application_files() {
  local source_file=""
  local target_file=""

  log "Deploying application files to $APP_TARGET_DIR"

  source_file="$SCRIPT_DIR/$APP_SCRIPT"
  target_file="$APP_TARGET_DIR/$APP_SCRIPT"
  if [[ "$source_file" != "$target_file" ]]; then
    install -m 755 "$source_file" "$target_file"
  else
    chmod 755 "$target_file"
  fi

  source_file="$SCRIPT_DIR/install.sh"
  target_file="$APP_TARGET_DIR/install.sh"
  if [[ "$source_file" != "$target_file" ]]; then
    install -m 755 "$source_file" "$target_file"
  else
    chmod 755 "$target_file"
  fi

  if [[ -f "$SCRIPT_DIR/README.md" ]]; then
    source_file="$SCRIPT_DIR/README.md"
    target_file="$APP_TARGET_DIR/README.md"
    if [[ "$source_file" != "$target_file" ]]; then
      install -m 644 "$source_file" "$target_file"
    fi
  fi

  cat > "$APP_TARGET_DIR/install.env" <<EOF
APP_ROOT="$APP_TARGET_DIR"
DATA_ROOT="$DATA_TARGET_DIR"
INSTALL_WRAPPER_PATH="$WRAPPER_PATH"
EOF
  chmod 644 "$APP_TARGET_DIR/install.env"
}

write_wrapper() {
  log "Creating command wrapper at $WRAPPER_PATH"

  cat > "$WRAPPER_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$APP_TARGET_DIR/$APP_SCRIPT" "\$@"
EOF

  chmod 755 "$WRAPPER_PATH"
}

print_install_summary() {
  log "Installation complete."
  log "Command: $WRAPPER_PATH"
  log "App files: $APP_TARGET_DIR"

  if [[ "$OS" == "linux" ]]; then
    log "Data: $DATA_TARGET_DIR"
  else
    log "Data: $APP_TARGET_DIR/output"
  fi

  log "Run: sudo ${APP_NAME}"
  log "Uninstall later with: sudo ${APP_NAME} --uninstall"
}

detect_os
require_root
install_dependencies
prepare_target_directories
deploy_application_files
write_wrapper
print_install_summary
