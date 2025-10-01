#!/usr/bin/env bash
#
# SSH Configuration Installer
# Installs modular SSH config across macOS, Linux, BSD, WSL
#
# Usage:
#   ./install.sh                        # Interactive install (copy mode)
#   ./install.sh --symlink              # Install using symlinks
#   ./install.sh --method copy          # Explicit copy mode
#   ./install.sh --method symlink       # Explicit symlink mode
#   ./install.sh --force                # Force overwrite
#   ./install.sh --dry-run              # Show what would happen
#   ./install.sh --uninstall            # Remove installation (manifest-based)
#
# Installation Methods:
#   copy      - Copies files (default, self-contained, survives repo deletion)
#   symlink   - Creates symlinks (live updates, requires repo to remain)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="${HOME}/.ssh"
CONFIG_FILE="${SSH_DIR}/config"
CONFIG_D_DIR="${SSH_DIR}/config.d"
SOCKETS_DIR="${SSH_DIR}/sockets"
MANIFEST_FILE="${SSH_DIR}/.dotfiles_manifest"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
FORCE=false
UNINSTALL=false
QUIET=false
INSTALL_METHOD="copy"  # Default: copy (can be 'copy' or 'symlink')

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  SSH Configuration Installer${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

log_info() {
    [[ "$QUIET" == true ]] && return
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    [[ "$QUIET" == true ]] && return
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    [[ "$QUIET" == true ]] && return
    echo -e "${MAGENTA}[STEP]${NC} $*"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    local yn
    while true; do
        if [[ "$default" == "y" ]]; then
            read -rp "$(echo -e "${YELLOW}${prompt} [Y/n]:${NC} ")" yn
            yn=${yn:-y}
        else
            read -rp "$(echo -e "${YELLOW}${prompt} [y/N]:${NC} ")" yn
            yn=${yn:-n}
        fi

        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

detect_os() {
    local os=""
    local arch=""

    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            os="wsl"
        else
            os="linux"
        fi
    elif [[ "$OSTYPE" == "freebsd"* ]] || [[ "$OSTYPE" == "openbsd"* ]]; then
        os="bsd"
    else
        os="unknown"
    fi

    # Detect architecture
    arch="$(uname -m)"

    echo "${os}:${arch}"
}

# ============================================================================
# Manifest Management
# ============================================================================

manifest_init() {
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    # Create new manifest
    cat > "$MANIFEST_FILE" << EOF
# Dotfiles SSH Configuration Manifest
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Method: ${INSTALL_METHOD}
# Script: ${SCRIPT_DIR}/install.sh

[metadata]
install_date=$(date +%s)
install_method=${INSTALL_METHOD}
source_dir=${SCRIPT_DIR}
installer_version=1.0.0

[files]
EOF

    chmod 600 "$MANIFEST_FILE"
    log_info "Initialized installation manifest"
}

manifest_add() {
    local file_type="$1"  # file, dir, symlink
    local path="$2"
    local source="${3:-}"

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    echo "${file_type}:${path}:${source}" >> "$MANIFEST_FILE"
}

manifest_read() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        return 1
    fi

    # Extract metadata
    local method
    method=$(grep "^install_method=" "$MANIFEST_FILE" | cut -d= -f2)

    echo "$method"
}

manifest_exists() {
    [[ -f "$MANIFEST_FILE" ]]
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_environment() {
    log_step "Validating environment..."

    # Check if running as root (not recommended)
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root is not recommended for SSH config"
        if ! prompt_yes_no "Continue anyway?"; then
            exit 1
        fi
    fi

    # Check for required commands
    local missing_commands=()
    for cmd in mkdir chmod rm; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    # Check for symlink support if using symlink method
    if [[ "$INSTALL_METHOD" == "symlink" ]]; then
        if ! command -v ln &> /dev/null; then
            log_error "Symlink method requires 'ln' command"
            exit 1
        fi
    fi

    # Check for cp command if using copy method
    if [[ "$INSTALL_METHOD" == "copy" ]]; then
        if ! command -v cp &> /dev/null; then
            missing_commands+=("cp")
        fi
    fi

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        exit 1
    fi

    # Detect OS
    local os_info
    os_info="$(detect_os)"
    local os="${os_info%%:*}"
    local arch="${os_info##*:}"

    log_info "Detected OS: ${os} (${arch})"
    log_info "Installation method: ${INSTALL_METHOD}"

    echo "$os"
}

validate_source_files() {
    log_step "Validating source files..."

    if [[ ! -f "${SCRIPT_DIR}/config" ]]; then
        log_error "Source config file not found: ${SCRIPT_DIR}/config"
        exit 1
    fi

    if [[ ! -d "${SCRIPT_DIR}/config.d" ]]; then
        log_error "Source config.d directory not found: ${SCRIPT_DIR}/config.d"
        exit 1
    fi

    local conf_count
    conf_count=$(find "${SCRIPT_DIR}/config.d" -maxdepth 1 -name "*.conf" | wc -l)

    if [[ $conf_count -eq 0 ]]; then
        log_error "No .conf files found in ${SCRIPT_DIR}/config.d"
        exit 1
    fi

    log_success "Found ${conf_count} configuration file(s)"

    # Validate script directory is absolute path for symlinks
    if [[ "$INSTALL_METHOD" == "symlink" ]]; then
        if [[ "${SCRIPT_DIR}" != /* ]]; then
            log_error "Script directory must be absolute path for symlinks: ${SCRIPT_DIR}"
            exit 1
        fi
    fi
}

# ============================================================================
# Backup Functions
# ============================================================================

backup_existing_config() {
    log_step "Checking for existing SSH configuration..."

    local needs_backup=false

    if [[ -f "$CONFIG_FILE" ]] || [[ -d "$CONFIG_D_DIR" ]]; then
        needs_backup=true
    fi

    if [[ "$needs_backup" == false ]]; then
        log_info "No existing configuration found (fresh install)"
        return 0
    fi

    # Check if it's our installation
    local existing_method=""
    if manifest_exists; then
        existing_method=$(manifest_read)
        log_info "Detected existing installation (method: ${existing_method})"
    fi

    log_warning "Existing SSH configuration detected"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would backup existing configuration"
        return 0
    fi

    if [[ "$FORCE" == false ]]; then
        if ! prompt_yes_no "Backup existing configuration?"; then
            log_error "Installation cancelled"
            exit 1
        fi
    fi

    # Backup config file
    if [[ -f "$CONFIG_FILE" ]] || [[ -L "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}${BACKUP_SUFFIX}"
        if [[ -L "$CONFIG_FILE" ]]; then
            # It's a symlink, backup the link target info
            cp -P "$CONFIG_FILE" "$backup_file" 2>/dev/null || cp "$CONFIG_FILE" "$backup_file"
        else
            cp -p "$CONFIG_FILE" "$backup_file"
        fi
        log_success "Backed up config to: ${backup_file}"
    fi

    # Backup config.d directory
    if [[ -d "$CONFIG_D_DIR" ]] && [[ ! -L "$CONFIG_D_DIR" ]]; then
        local backup_dir="${CONFIG_D_DIR}${BACKUP_SUFFIX}"
        cp -rp "$CONFIG_D_DIR" "$backup_dir"
        log_success "Backed up config.d to: ${backup_dir}"
    elif [[ -L "$CONFIG_D_DIR" ]]; then
        # It's a symlink
        local backup_link="${CONFIG_D_DIR}${BACKUP_SUFFIX}.link"
        readlink "$CONFIG_D_DIR" > "$backup_link"
        log_success "Backed up config.d symlink target to: ${backup_link}"
    fi

    # Backup manifest if exists
    if [[ -f "$MANIFEST_FILE" ]]; then
        cp -p "$MANIFEST_FILE" "${MANIFEST_FILE}${BACKUP_SUFFIX}"
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

create_directories() {
    log_step "Creating directory structure..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would create: ${SSH_DIR}"
        log_info "[DRY-RUN] Would create: ${CONFIG_D_DIR}"
        log_info "[DRY-RUN] Would create: ${SOCKETS_DIR}"
        return 0
    fi

    # Create SSH directory
    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        manifest_add "dir" "$SSH_DIR"
    fi

    # Create sockets directory
    if [[ ! -d "$SOCKETS_DIR" ]]; then
        mkdir -p "$SOCKETS_DIR"
        manifest_add "dir" "$SOCKETS_DIR"
    fi

    # Create config.d directory (only if not symlinking the whole dir)
    if [[ "$INSTALL_METHOD" == "copy" ]]; then
        if [[ ! -d "$CONFIG_D_DIR" ]]; then
            mkdir -p "$CONFIG_D_DIR"
            manifest_add "dir" "$CONFIG_D_DIR"
        fi
    fi

    log_success "Created directory structure"
}

install_file() {
    local source="$1"
    local target="$2"
    local method="$3"  # copy or symlink

    # Remove existing file/symlink
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        rm -f "$target"
    fi

    if [[ "$method" == "symlink" ]]; then
        ln -sf "$source" "$target"
        manifest_add "symlink" "$target" "$source"
        return 0
    else
        cp -f "$source" "$target"
        manifest_add "file" "$target" "$source"
        return 0
    fi
}

install_config_files() {
    log_step "Installing configuration files (method: ${INSTALL_METHOD})..."

    local os="$1"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install config files using ${INSTALL_METHOD}"
        return 0
    fi

    # Install main config file
    install_file "${SCRIPT_DIR}/config" "$CONFIG_FILE" "$INSTALL_METHOD"
    log_success "Installed main config: ${CONFIG_FILE}"

    # Install config.d files
    local installed_count=0

    # If using symlink method for everything, we could symlink the entire directory
    # But for flexibility, we'll symlink individual files to allow per-file control

    while IFS= read -r -d '' conf_file; do
        local filename
        filename="$(basename "$conf_file")"

        # Platform-specific handling
        local target_file="${CONFIG_D_DIR}/${filename}"

        case "$filename" in
            01-workstation-mac.conf)
                if [[ "$os" != "macos" ]]; then
                    target_file="${CONFIG_D_DIR}/${filename}.disabled"
                    log_info "Installing ${filename} as disabled (non-macOS system)"
                fi
                ;;
            01-workstation-linux.conf)
                if [[ "$os" == "macos" ]]; then
                    target_file="${CONFIG_D_DIR}/${filename}.disabled"
                    log_info "Installing ${filename} as disabled (macOS system)"
                fi
                ;;
        esac

        # Ensure config.d directory exists
        if [[ ! -d "$CONFIG_D_DIR" ]]; then
            mkdir -p "$CONFIG_D_DIR"
            manifest_add "dir" "$CONFIG_D_DIR"
        fi

        install_file "$conf_file" "$target_file" "$INSTALL_METHOD"
        ((installed_count++))

    done < <(find "${SCRIPT_DIR}/config.d" -maxdepth 1 -name "*.conf" -print0)

    log_success "Installed ${installed_count} configuration file(s)"
}

set_permissions() {
    log_step "Setting secure permissions..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would set permissions"
        return 0
    fi

    # SSH directory
    chmod 700 "$SSH_DIR"

    # Config file (follow symlink if needed)
    if [[ -f "$CONFIG_FILE" ]] || [[ -L "$CONFIG_FILE" ]]; then
        if [[ -L "$CONFIG_FILE" ]]; then
            # For symlinks, set permission on the target
            chmod 600 "$(readlink -f "$CONFIG_FILE" 2>/dev/null || readlink "$CONFIG_FILE")" 2>/dev/null || true
        else
            chmod 600 "$CONFIG_FILE"
        fi
    fi

    # Config.d directory and contents
    if [[ -d "$CONFIG_D_DIR" ]] && [[ ! -L "$CONFIG_D_DIR" ]]; then
        chmod 700 "$CONFIG_D_DIR"

        # Set permissions on config files (follow symlinks)
        while IFS= read -r -d '' conf_file; do
            if [[ -L "$conf_file" ]]; then
                # For symlinks, set permission on target
                local target
                target=$(readlink -f "$conf_file" 2>/dev/null || readlink "$conf_file")
                chmod 600 "$target" 2>/dev/null || true
            else
                chmod 600 "$conf_file"
            fi
        done < <(find "$CONFIG_D_DIR" -type f -print0)
    fi

    # Sockets directory
    if [[ -d "$SOCKETS_DIR" ]]; then
        chmod 700 "$SOCKETS_DIR"
    fi

    # Manifest file
    if [[ -f "$MANIFEST_FILE" ]]; then
        chmod 600 "$MANIFEST_FILE"
    fi

    log_success "Set secure permissions (700 for dirs, 600 for files)"
}

verify_installation() {
    log_step "Verifying installation..."

    local errors=0

    # Check directories exist
    for dir in "$SSH_DIR" "$SOCKETS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Directory missing: ${dir}"
            ((errors++))
        fi
    done

    # Check config file exists (file or symlink)
    if [[ ! -f "$CONFIG_FILE" ]] && [[ ! -L "$CONFIG_FILE" ]]; then
        log_error "Config file missing: ${CONFIG_FILE}"
        ((errors++))
    fi

    # Check config.d exists
    if [[ ! -d "$CONFIG_D_DIR" ]] && [[ ! -L "$CONFIG_D_DIR" ]]; then
        log_error "Config.d directory missing: ${CONFIG_D_DIR}"
        ((errors++))
    fi

    # Verify symlinks if using symlink method
    if [[ "$INSTALL_METHOD" == "symlink" ]]; then
        if [[ -L "$CONFIG_FILE" ]]; then
            if [[ ! -e "$CONFIG_FILE" ]]; then
                log_error "Broken symlink: ${CONFIG_FILE}"
                ((errors++))
            else
                log_success "Config symlink is valid"
            fi
        fi
    fi

    # Check manifest exists
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_warning "Manifest file not created (non-critical)"
    fi

    # Check permissions
    local ssh_perms
    if command -v stat &> /dev/null; then
        ssh_perms=$(stat -f "%Lp" "$SSH_DIR" 2>/dev/null || stat -c "%a" "$SSH_DIR" 2>/dev/null || echo "unknown")
        if [[ "$ssh_perms" != "700" ]] && [[ "$ssh_perms" != "unknown" ]]; then
            log_warning "SSH directory permissions are ${ssh_perms}, should be 700"
        fi
    fi

    # Validate SSH config syntax
    if command -v ssh &> /dev/null; then
        if ssh -G localhost &> /dev/null; then
            log_success "SSH config syntax is valid"
        else
            log_error "SSH config syntax validation failed"
            log_error "Run: ssh -G localhost  # for details"
            ((errors++))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Installation verified successfully"
        return 0
    else
        log_error "Installation verification failed with ${errors} error(s)"
        return 1
    fi
}

# ============================================================================
# Uninstall Function (Manifest-Based)
# ============================================================================

uninstall_config() {
    log_step "Uninstalling SSH configuration..."

    # Check for manifest
    if ! manifest_exists; then
        log_warning "No manifest found. Falling back to standard uninstall..."
        uninstall_config_legacy
        return
    fi

    # Read installation method from manifest
    local install_method
    install_method=$(manifest_read)
    log_info "Detected installation method: ${install_method}"

    # Parse manifest and show what will be removed
    log_warning "The following will be removed:"

    local files_to_remove=()
    local dirs_to_remove=()

    while IFS=: read -r type path source; do
        [[ "$type" == "[files]" ]] && continue
        [[ -z "$type" ]] && continue
        [[ "$type" == "#"* ]] && continue

        case "$type" in
            file|symlink)
                if [[ -e "$path" ]] || [[ -L "$path" ]]; then
                    files_to_remove+=("$path")
                    echo "  - ${path}"
                fi
                ;;
            dir)
                if [[ -d "$path" ]] && [[ "$path" != "$SSH_DIR" ]]; then
                    dirs_to_remove+=("$path")
                    echo "  - ${path}/"
                fi
                ;;
        esac
    done < <(grep -A 9999 "^\[files\]" "$MANIFEST_FILE")

    echo "  - ${MANIFEST_FILE} (manifest)"

    if [[ ${#files_to_remove[@]} -eq 0 ]] && [[ ${#dirs_to_remove[@]} -eq 0 ]]; then
        log_info "No files found to remove (already clean)"
        rm -f "$MANIFEST_FILE"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would remove ${#files_to_remove[@]} files and ${#dirs_to_remove[@]} directories"
        return 0
    fi

    if ! prompt_yes_no "Remove these files?" "n"; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    # Create backup before uninstalling
    backup_existing_config

    # Remove files and symlinks
    for file in "${files_to_remove[@]}"; do
        if [[ -L "$file" ]]; then
            rm -f "$file"
            log_success "Removed symlink: ${file}"
        elif [[ -f "$file" ]]; then
            rm -f "$file"
            log_success "Removed file: ${file}"
        fi
    done

    # Remove directories (in reverse order to handle nested dirs)
    for dir in "${dirs_to_remove[@]}"; do
        if [[ -d "$dir" ]]; then
            # Only remove if empty or only contains our files
            if rmdir "$dir" 2>/dev/null; then
                log_success "Removed directory: ${dir}"
            else
                log_warning "Directory not empty, skipping: ${dir}"
            fi
        fi
    done

    # Remove manifest
    rm -f "$MANIFEST_FILE"

    log_success "Uninstallation complete (backup created)"
}

uninstall_config_legacy() {
    # Legacy uninstall for installations without manifest

    if [[ ! -f "$CONFIG_FILE" ]] && [[ ! -d "$CONFIG_D_DIR" ]]; then
        log_info "No installation found to remove"
        return 0
    fi

    log_warning "This will remove:"
    [[ -f "$CONFIG_FILE" ]] && echo "  - ${CONFIG_FILE}"
    [[ -d "$CONFIG_D_DIR" ]] && echo "  - ${CONFIG_D_DIR}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would remove configuration"
        return 0
    fi

    if ! prompt_yes_no "Are you sure you want to uninstall?" "n"; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    # Create backup before uninstalling
    backup_existing_config

    # Remove files
    [[ -f "$CONFIG_FILE" ]] || [[ -L "$CONFIG_FILE" ]] && rm -f "$CONFIG_FILE"
    [[ -d "$CONFIG_D_DIR" ]] && rm -rf "$CONFIG_D_DIR"

    log_success "Uninstallation complete (backup created)"
}

# ============================================================================
# Post-Install Information
# ============================================================================

print_post_install_info() {
    local os="$1"

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""

    echo -e "${CYAN}📁 Installation Details:${NC}"
    echo "   Method: ${INSTALL_METHOD}"
    echo "   Config: ${CONFIG_FILE}"
    if [[ "$INSTALL_METHOD" == "symlink" ]]; then
        echo "           → $(readlink "$CONFIG_FILE" 2>/dev/null || echo "N/A")"
    fi
    echo "   Modules: ${CONFIG_D_DIR}"
    echo "   Sockets: ${SOCKETS_DIR}"
    echo "   Manifest: ${MANIFEST_FILE}"
    echo ""

    if [[ "$INSTALL_METHOD" == "symlink" ]]; then
        echo -e "${CYAN}🔗 Symlink Mode Benefits:${NC}"
        echo "   ✅ Live updates from dotfiles repo"
        echo "   ✅ No need to re-run install after git pull"
        echo "   ⚠️  Requires dotfiles repo to remain at: ${SCRIPT_DIR}"
        echo ""
    else
        echo -e "${CYAN}📋 Copy Mode Benefits:${NC}"
        echo "   ✅ Self-contained (survives repo deletion)"
        echo "   ✅ No dependency on dotfiles location"
        echo "   ℹ️  Run install.sh again after updating dotfiles"
        echo ""
    fi

    echo -e "${CYAN}🔧 Next Steps:${NC}"
    echo ""
    echo "1. Generate SSH key (if you haven't already):"
    echo "   ${GREEN}ssh-keygen -t ed25519 -C \"your-email@example.com\"${NC}"
    echo ""

    if [[ "$os" == "macos" ]]; then
        echo "2. Add key to macOS Keychain:"
        echo "   ${GREEN}ssh-add --apple-use-keychain ~/.ssh/id_ed25519${NC}"
        echo ""
    else
        echo "2. Add key to SSH agent:"
        echo "   ${GREEN}eval \"\$(ssh-agent -s)\"${NC}"
        echo "   ${GREEN}ssh-add ~/.ssh/id_ed25519${NC}"
        echo ""
    fi

    echo "3. Customize your hosts in:"
    echo "   ${GREEN}${CONFIG_D_DIR}/50-my-hosts.conf${NC}"
    echo "   (copy from 99-example.conf)"
    echo ""

    echo "4. Test configuration:"
    echo "   ${GREEN}ssh -G hostname${NC}  # Show effective config"
    echo "   ${GREEN}ssh -T git@github.com${NC}  # Test GitHub"
    echo ""

    echo -e "${CYAN}📚 Documentation:${NC}"
    echo "   ${SCRIPT_DIR}/README.md"
    echo ""

    if [[ -f "${SSH_DIR}/config${BACKUP_SUFFIX}" ]]; then
        echo -e "${YELLOW}⚠️  Backup created:${NC}"
        echo "   ${SSH_DIR}/config${BACKUP_SUFFIX}"
        [[ -d "${SSH_DIR}/config.d${BACKUP_SUFFIX}" ]] && echo "   ${SSH_DIR}/config.d${BACKUP_SUFFIX}"
        [[ -f "${MANIFEST_FILE}${BACKUP_SUFFIX}" ]] && echo "   ${MANIFEST_FILE}${BACKUP_SUFFIX}"
        echo ""
    fi
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --symlink|-s)
                INSTALL_METHOD="symlink"
                shift
                ;;
            --method|-m)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "--method requires an argument (copy|symlink)"
                    exit 1
                fi
                case "$1" in
                    copy|symlink)
                        INSTALL_METHOD="$1"
                        ;;
                    *)
                        log_error "Invalid method: $1 (must be 'copy' or 'symlink')"
                        exit 1
                        ;;
                esac
                shift
                ;;
            --uninstall|-u)
                UNINSTALL=true
                shift
                ;;
            --quiet|-q)
                QUIET=true
                shift
                ;;
            --help|-h)
                cat << EOF
SSH Configuration Installer v2.0

Usage:
  $0 [OPTIONS]

Installation Methods:
  copy      Create independent copies of config files (default)
            ✅ Self-contained, survives repo deletion
            ❌ Requires re-run after dotfiles updates

  symlink   Create symbolic links to dotfiles repo
            ✅ Live updates, no re-install needed
            ❌ Breaks if repo is moved/deleted

Options:
  --method, -m <copy|symlink>   Set installation method explicitly
  --symlink, -s                 Shortcut for --method symlink
  --force, -f                   Skip confirmation prompts
  --dry-run                     Show what would be done without changes
  --uninstall, -u               Remove installation (manifest-based)
  --quiet, -q                   Minimal output
  --help, -h                    Show this help message

Examples:
  $0                            # Interactive install (copy mode)
  $0 --symlink                  # Install with symlinks
  $0 --method copy --force      # Force copy install
  $0 --dry-run --symlink        # Preview symlink install
  $0 --uninstall                # Remove installation

One-liner install:
  # Copy mode (default)
  curl -fsSL https://raw.githubusercontent.com/khodaparastan/ssh-config/main/install.sh | bash

  # Symlink mode
  git clone https://github.com/khodaparastan/ssh-config.git ~/dotfiles
  ~/dotfiles/ssh/install.sh --symlink

Trade-offs:
  Copy Mode:
    - Config survives if you delete dotfiles repo
    - Must re-run install.sh after updating dotfiles
    - Good for: Stable setups, shared configs

  Symlink Mode:
    - git pull in dotfiles automatically updates SSH config
    - Config breaks if dotfiles repo is moved/deleted
    - Good for: Active dotfiles development, GNU Stow users

EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Print header
    if [[ "$QUIET" == false ]]; then
        print_header
    fi

    # Handle uninstall
    if [[ "$UNINSTALL" == true ]]; then
        uninstall_config
        exit 0
    fi

    # Validate environment
    local os
    os=$(validate_environment)

    # Validate source files
    validate_source_files

    # Initialize manifest
    manifest_init

    # Backup existing config
    backup_existing_config

    # Create directory structure
    create_directories

    # Install configuration files
    install_config_files "$os"

    # Set secure permissions
    set_permissions

    # Verify installation
    if ! verify_installation; then
        log_error "Installation completed with errors"
        exit 1
    fi

    # Print post-install information
    if [[ "$QUIET" == false ]] && [[ "$DRY_RUN" == false ]]; then
        print_post_install_info "$os"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "Dry run complete. No changes were made."
        log_info "Run without --dry-run to perform actual installation."
    fi
}

# Run main function
main "$@"
