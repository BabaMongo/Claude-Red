#!/usr/bin/env bash
# claude-red VPS installer
# Automates Claude Code installation and claude-red skills setup on a VPS.
#
# Usage:
#   ./install-vps.sh                        # interactive
#   ./install-vps.sh --install-all          # install everything (Claude Code + skills)
#   ./install-vps.sh --claude-only          # install only Claude Code CLI
#   ./install-vps.sh --skills-only          # install only claude-red skills
#   ./install-vps.sh --systemd              # also set up systemd service
#   ./install-vps.sh --dry-run              # show what would happen
#   ./install-vps.sh --help                 # show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
SKILLS_TARGET="${CLAUDE_HOME}/skills/claude-red"

INSTALL_CLAUDE=0
INSTALL_SKILLS=0
SETUP_SYSTEMD=0
DRY_RUN=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[-]\033[0m %s\n' "$1" >&2; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

check_node() {
  if command -v node >/dev/null 2>&1; then
    local ver
    ver=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$ver" -ge 18 ]; then
      return 0
    fi
    warn "Node.js $(node --version) found, but v18+ is required."
    return 1
  fi
  return 1
}

install_node() {
  local os
  os=$(detect_os)
  log "Installing Node.js 18+..."
  case "$os" in
    ubuntu|debian)
      run curl -fsSL https://deb.nodesource.com/setup_18.x -o /tmp/nodesource_setup.sh
      run sudo -E bash /tmp/nodesource_setup.sh
      run sudo apt-get install -y nodejs
      ;;
    centos|rhel|fedora)
      run curl -fsSL https://rpm.nodesource.com/setup_18.x -o /tmp/nodesource_setup.sh
      run sudo -E bash /tmp/nodesource_setup.sh
      run sudo yum install -y nodejs
      ;;
    *)
      err "Unsupported OS '$os'. Install Node.js 18+ manually and re-run with --skills-only."
      return 1
      ;;
  esac
  ok "Node.js installed."
}

install_claude_code() {
  log "Installing Claude Code CLI..."
  if ! check_node; then
    install_node
  else
    ok "Node.js $(node --version) already present."
  fi
  run npm install -g @anthropic-ai/claude-code
  if [ "$DRY_RUN" -eq 0 ] && command -v claude >/dev/null 2>&1; then
    ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'version check unavailable')"
  else
    ok "Claude Code install step complete."
  fi
}

install_skills() {
  log "Installing claude-red skills to $SKILLS_TARGET..."
  if [ ! -x "$SCRIPT_DIR/install.sh" ]; then
    err "install.sh not found in $SCRIPT_DIR"
    return 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    run "$SCRIPT_DIR/install.sh" --target "$SKILLS_TARGET" --dry-run
  else
    "$SCRIPT_DIR/install.sh" --target "$SKILLS_TARGET"
  fi
  ok "Skills installed."
}

setup_config() {
  log "Ensuring Claude config directory exists..."
  run mkdir -p "$CLAUDE_HOME"
  if [ ! -f "$CLAUDE_HOME/config.json" ] && [ "$DRY_RUN" -eq 0 ]; then
    cat > "$CLAUDE_HOME/config.json" << 'EOF'
{
  "model": "claude-3-5-sonnet",
  "temperature": 0.7
}
EOF
    chmod 600 "$CLAUDE_HOME/config.json"
    warn "Created $CLAUDE_HOME/config.json — add your ANTHROPIC_API_KEY via env var or this file."
  else
    ok "Config directory ready."
  fi
}

setup_systemd() {
  log "Setting up systemd service..."
  local svc="/etc/systemd/system/claude-code.service"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] Would write $svc and enable it."
    return 0
  fi
  sudo tee "$svc" > /dev/null << EOF
[Unit]
Description=Claude Code Service
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${HOME}
Environment="ANTHROPIC_API_KEY="
ExecStart=$(command -v claude || echo /usr/local/bin/claude) --daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  warn "Systemd service written to $svc. Set ANTHROPIC_API_KEY in the unit before starting."
  warn "Enable with: sudo systemctl enable --now claude-code"
}

# Parse arguments
if [ $# -eq 0 ]; then
  # Interactive default
  INSTALL_CLAUDE=1
  INSTALL_SKILLS=1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --install-all) INSTALL_CLAUDE=1; INSTALL_SKILLS=1; shift ;;
    --claude-only) INSTALL_CLAUDE=1; shift ;;
    --skills-only) INSTALL_SKILLS=1; shift ;;
    --systemd)     SETUP_SYSTEMD=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage 0 ;;
    *)             err "Unknown option: $1"; usage 1 ;;
  esac
done

log "claude-red VPS installer"
[ "$DRY_RUN" -eq 1 ] && warn "Running in dry-run mode — no changes will be made."
echo

if [ "$INSTALL_CLAUDE" -eq 1 ]; then
  install_claude_code
  setup_config
  echo
fi

if [ "$INSTALL_SKILLS" -eq 1 ]; then
  install_skills
  echo
fi

if [ "$SETUP_SYSTEMD" -eq 1 ]; then
  setup_systemd
  echo
fi

ok "Done."
echo
log "Next steps:"
echo "  1. Set your API key:  export ANTHROPIC_API_KEY=\"your-key-here\""
echo "  2. Start a session:   claude"
echo "  3. Skills auto-load from $SKILLS_TARGET"
