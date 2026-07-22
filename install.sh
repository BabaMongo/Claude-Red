#!/usr/bin/env bash
# claude-red installer
# Copies offensive security skills into a Claude skills directory.
#
# Usage:
#   ./install.sh                                # interactive (asks for target)
#   ./install.sh --target ~/.claude/skills      # explicit target
#   ./install.sh --category web                 # one category only
#   ./install.sh --target DIR --category web    # combined
#   ./install.sh --list                         # list available categories
#   ./install.sh --dry-run                      # show what would be copied
#   ./install.sh --verify                       # verify existing installation
#   ./install.sh --uninstall TARGET             # remove installed skills
#
# Options:
#   --verbose                                   # show detailed output
#   --force                                     # skip confirmations
#   --backup                                    # backup existing installation
#
# Default target: ~/.claude/skills/claude-red

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/Skills"
DEFAULT_TARGET="${HOME}/.claude/skills/claude-red"

TARGET=""
CATEGORY=""
DRY_RUN=0
LIST_ONLY=0
VERIFY_ONLY=0
UNINSTALL_ONLY=0
VERBOSE=0
FORCE=0
BACKUP=0

# Color output (auto-disable if not a TTY)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

list_categories() {
  echo "Available categories:"
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    count=$(find "$d" -name SKILL.md | wc -l | tr -d ' ')
    printf "  %-20s %s skill(s)\n" "$name" "$count"
  done
}

confirm() {
  if [ "$FORCE" -eq 1 ]; then
    return 0
  fi
  local prompt="$1"
  local response
  read -r -p "${prompt} (y/n) " response
  [ "$response" = "y" ] || [ "$response" = "Y" ]
}

count_skills() {
  local source="$1"
  find "$source" -name SKILL.md 2>/dev/null | wc -l | tr -d ' '
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)     TARGET="$2"; shift 2 ;;
    --category)   CATEGORY="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --list)       LIST_ONLY=1; shift ;;
    --verify)     VERIFY_ONLY=1; shift ;;
    --uninstall)  UNINSTALL_ONLY=1; TARGET="$2"; shift 2 ;;
    --verbose)    VERBOSE=1; shift ;;
    --force)      FORCE=1; shift ;;
    --backup)     BACKUP=1; shift ;;
    -h|--help)    usage 0 ;;
    *)            log_error "Unknown option: $1"; usage 1 ;;
  esac
done

if [ "$LIST_ONLY" -eq 1 ]; then
  list_categories
  exit 0
fi

# Validate source skills directory
if [ ! -d "$SKILLS_DIR" ]; then
  log_error "Skills directory not found at $SKILLS_DIR"
  exit 1
fi

# Check for at least one SKILL.md file
skill_count=$(count_skills "$SKILLS_DIR")
if [ "$skill_count" -eq 0 ]; then
  log_error "No SKILL.md files found in $SKILLS_DIR"
  exit 1
fi

if [ "$VERBOSE" -eq 1 ]; then
  log_info "Found $skill_count skills in $SKILLS_DIR"
fi

verify_installation() {
  local dest="$1"
  if [ ! -d "$dest" ]; then
    log_warn "Installation directory not found: $dest"
    return 1
  fi

  local installed=$(count_skills "$dest")
  if [ "$installed" -eq 0 ]; then
    log_warn "No skills found in $dest"
    return 1
  fi

  log_success "Found $installed skill(s) installed in $dest"

  if [ "$VERBOSE" -eq 1 ]; then
    echo "Installed skills:"
    find "$dest" -name SKILL.md -type f | sed 's|^|  |' | sort
  fi

  return 0
}

uninstall_skills() {
  local dest="$1"
  if [ ! -d "$dest" ]; then
    log_error "Installation directory not found: $dest"
    return 1
  fi

  local skill_count=$(count_skills "$dest")
  if [ "$skill_count" -eq 0 ]; then
    log_warn "No skills found to uninstall in $dest"
    return 0
  fi

  log_warn "This will remove $skill_count skill(s) from $dest"
  if ! confirm "Continue with uninstall?"; then
    log_info "Uninstall cancelled"
    return 0
  fi

  rm -rf "$dest"
  log_success "Uninstalled skills from $dest"
  return 0
}

# Handle verify-only mode
if [ "$VERIFY_ONLY" -eq 1 ]; then
  if [ -z "$TARGET" ]; then
    TARGET="$DEFAULT_TARGET"
  fi
  if verify_installation "$TARGET"; then
    exit 0
  else
    exit 1
  fi
fi

# Handle uninstall mode
if [ "$UNINSTALL_ONLY" -eq 1 ]; then
  if [ -z "$TARGET" ]; then
    log_error "Target directory required for uninstall"
    usage 1
  fi
  uninstall_skills "$TARGET"
  exit $?
fi

# Interactive prompt if no target given
if [ -z "$TARGET" ]; then
  if [ -t 0 ]; then
    read -r -p "Install target [$DEFAULT_TARGET]: " TARGET || true
  fi
  TARGET="${TARGET:-$DEFAULT_TARGET}"
fi

# Expand tilde in target path
TARGET="${TARGET/#\~/$HOME}"

# Validate category if specified
if [ -n "$CATEGORY" ]; then
  if [ ! -d "$SKILLS_DIR/$CATEGORY" ]; then
    log_error "Category '$CATEGORY' not found"
    echo ""
    list_categories >&2
    exit 1
  fi
  SOURCE="$SKILLS_DIR/$CATEGORY"
  DEST="$TARGET/$CATEGORY"
else
  SOURCE="$SKILLS_DIR"
  DEST="$TARGET"
fi

log_info "Source: $SOURCE"
log_info "Target: $DEST"
echo

# Check if target exists and handle backup
if [ -d "$DEST" ] && [ "$(count_skills "$DEST")" -gt 0 ]; then
  log_warn "Installation already exists at $DEST"
  if [ "$BACKUP" -eq 1 ]; then
    BACKUP_DIR="${DEST}.backup.$(date +%s)"
    log_info "Creating backup at $BACKUP_DIR"
    cp -r "$DEST" "$BACKUP_DIR" || {
      log_error "Failed to create backup"
      exit 1
    }
    log_success "Backup created"
  elif ! confirm "Overwrite existing installation?"; then
    log_info "Installation cancelled"
    exit 0
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log_info "Dry run - would copy the following:"
  find "$SOURCE" -name SKILL.md 2>/dev/null | while read -r file; do
    rel_path="${file#$SOURCE/}"
    echo "  $DEST/$rel_path"
  done
  exit 0
fi

mkdir -p "$DEST"

# Use rsync if available for nicer output, else cp -r
if command -v rsync >/dev/null 2>&1; then
  log_info "Copying skills..."
  rsync -a --info=stats1 "$SOURCE/" "$DEST/" || {
    log_error "Failed to copy skills"
    exit 1
  }
else
  log_info "Copying skills (rsync not available)..."
  cp -r "$SOURCE/." "$DEST/" || {
    log_error "Failed to copy skills"
    exit 1
  }
fi

# Verify installation
echo
if verify_installation "$DEST"; then
  log_success "Installation complete"
  echo ""
  log_info "Claude will auto-discover these skills on next session start."
  log_info "To verify installation, run: $0 --verify --target $DEST"
else
  log_error "Installation verification failed"
  exit 1
fi
