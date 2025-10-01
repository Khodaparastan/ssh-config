# SSH Configuration

Modular, cross-platform SSH configuration with flexible installation options.

## 🚀 Quick Start

### Choose Your Installation Method

**Option 1: Copy Mode (Default)** - Self-contained, survives repo deletion

```bash
cd ~/dotfiles/ssh && ./install.sh
```

**Option 2: Symlink Mode** - Live updates from dotfiles

```bash
cd ~/dotfiles/ssh && ./install.sh --symlink
```

### One-Liner Installation

**From GitHub (Copy Mode):**

```bash
curl -fsSL https://raw.githubusercontent.com/khodaparastan/ssh-config/main/install.sh | bash
```

**From Local Dotfiles (Symlink Mode):**

```bash
git clone https://github.com/khodaparastan/ssh-config.git ~/dotfiles
~/dotfiles/ssh/install.sh --symlink
```

## 📊 Installation Method Comparison

| Feature | Copy Mode | Symlink Mode |
|---------|-----------|--------------|
| **Self-contained** | ✅ Yes | ❌ No |
| **Survives repo deletion** | ✅ Yes | ❌ No |
| **Auto-updates from git pull** | ❌ No | ✅ Yes |
| **Requires re-install after updates** | ✅ Yes | ❌ No |
| **Good for stable setups** | ✅ Yes | ⚠️ Maybe |
| **Good for dotfiles development** | ⚠️ Maybe | ✅ Yes |
| **Works with GNU Stow pattern** | ❌ No | ✅ Yes |
| **Safe for repo relocation** | ✅ Yes | ❌ No |

### When to Use Each Method

**Use Copy Mode if:**

- You want a stable, self-contained SSH configuration
- You might delete or move your dotfiles repo
- You prefer explicit updates (re-run install script)
- You're deploying to servers where dotfiles won't persist

**Use Symlink Mode if:**

- You actively develop/maintain your dotfiles
- You want automatic updates from `git pull`
- Your dotfiles repo location is permanent (`~/dotfiles`)
- You use GNU Stow or similar dotfiles managers

## 🛠️ Installation Options

```bash
# Interactive install (copy mode, default)
./install.sh

# Symlink mode
./install.sh --symlink
./install.sh --method symlink
./install.sh -s

# Copy mode (explicit)
./install.sh --method copy

# Force install without prompts
./install.sh --force
./install.sh --symlink --force

# Preview what will happen
./install.sh --dry-run
./install.sh --symlink --dry-run

# Quiet mode (minimal output)
./install.sh --quiet

# Uninstall (manifest-based)
./install.sh --uninstall
```

## 📦 What Gets Installed

```text
~/.ssh/
├── config                              # Main config
├── config.d/                           # Modular configs
│   ├── 00-global-defaults.conf
│   ├── 01-workstation-mac.conf         # Auto-enabled on macOS
│   ├── 01-workstation-linux.conf       # Auto-enabled on Linux
│   ├── 02-environment-defaults.conf
│   ├── 10-shared-patterns.conf
│   ├── 80-cloudflare-tunnels.conf
│   ├── 90-relay-servers.conf
│   └── 99-example.conf
├── sockets/                            # For multiplexing
└── .dotfiles_manifest                  # Installation manifest
```

### Installation Manifest

The installer creates `~/.ssh/.dotfiles_manifest` tracking:

- Installation method (copy vs symlink)
- Timestamp
- List of installed files/directories
- Source locations

This enables:

- ✅ Clean, precise uninstallation
- ✅ Detection of existing installations
- ✅ Safe upgrades between methods

## 🔄 Switching Between Methods

### From Copy to Symlink

```bash
./install.sh --uninstall          # Remove copy installation
./install.sh --symlink --force    # Install with symlinks
```

### From Symlink to Copy

```bash
./install.sh --uninstall          # Remove symlink installation
./install.sh --force              # Install with copies
```

## 🔧 Usage Examples

### Scenario 1: Stable Personal Setup (Copy Mode)

```bash
# Initial install
cd ~/dotfiles/ssh
./install.sh

# After updating dotfiles (manual update required)
git pull
./install.sh --force
```

### Scenario 2: Active Dotfiles Development (Symlink Mode)

```bash
# Initial install
cd ~/dotfiles/ssh
./install.sh --symlink

# After editing configs in repo
# No action needed! Changes are live immediately

# Test changes
ssh -G hostname

# If satisfied, commit
git add config.d/
git commit -m "Update SSH config"
```

### Scenario 3: Server Deployment (Copy Mode)

```bash
# Deploy to server
scp -r ssh/ user@server:~/dotfiles/
ssh user@server "~/dotfiles/ssh/install.sh --force --quiet"
```

### Scenario 4: Testing New Configuration

```bash
# Preview installation
./install.sh --dry-run --symlink

# Test temporarily
./install.sh --symlink
ssh -G test-host

# If not working, quick rollback
./install.sh --uninstall

# Restore from backup
cp ~/.ssh/config.backup.* ~/.ssh/config
```

## 🧪 Testing & Verification

```bash
# Show effective configuration for a host
ssh -G hostname

# Verify symlinks (if using symlink mode)
ls -la ~/.ssh/config
ls -la ~/.ssh/config.d/

# Check installation manifest
cat ~/.ssh/.dotfiles_manifest

# Test syntax
ssh -G localhost >/dev/null && echo "✅ Valid" || echo "❌ Invalid"

# List all configured hosts
grep -h "^Host " ~/.ssh/config.d/*.conf | sort -u
```

## 🔐 Security Considerations

Both installation methods are equally secure:

- Files/symlinks set to `600` permissions
- Directories set to `700` permissions
- Symlinks don't expose additional attack surface
- Source files in dotfiles repo should also be `600`

**Symlink Mode Additional Considerations:**

- Ensure dotfiles repo has proper permissions
- Don't store dotfiles on world-readable locations
- If multi-user system, keep dotfiles in your `$HOME`

## 🗑️ Uninstallation

The installer creates a manifest tracking everything it installs:

```bash
# Clean uninstall (reads manifest)
./install.sh --uninstall

# This will:
# 1. Show what will be removed
# 2. Ask for confirmation
# 3. Create timestamped backup
# 4. Remove all tracked files/dirs
# 5. Clean up manifest
```

## 🔄 Integration with Dotfiles Managers

### GNU Stow

Symlink mode works perfectly with Stow:

```bash
# Use installer instead of stow
cd ~/dotfiles/ssh
./install.sh --symlink

# Result is similar to:
# cd ~/dotfiles && stow ssh
```

### Chezmoi

```toml
# .chezmoiexternal.toml
[".ssh/config"]
    type = "file"
    url = "https://github.com/khodaparastan/ssh-config/raw/main/config"
    refreshPeriod = "168h"

# Or use script:
# run_once_install-ssh-config.sh
#!/bin/bash
~/dotfiles/ssh/install.sh --method copy --force
```

### YADM

```bash
# After yadm clone
yadm clone https://github.com/khodaparastan/ssh-config.git
cd ~/.local/share/yadm/repo/ssh
./install.sh --symlink
```

## 🐛 Troubleshooting

### Broken Symlinks

```bash
# Check symlink targets
ls -la ~/.ssh/config
readlink ~/.ssh/config

# If broken (repo moved)
./install.sh --uninstall
# Move repo back, or switch to copy mode:
./install.sh --method copy
```

### Permission Errors

```bash
# Fix permissions (works for both modes)
chmod 700 ~/.ssh ~/.ssh/sockets
chmod 600 ~/.ssh/config
find ~/.ssh/config.d -type f -exec chmod 600 {} \;
```

### Updates Not Reflecting (Copy Mode)

```bash
# Must re-run installer
cd ~/dotfiles/ssh
./install.sh --force
```

### Config Not Loading

```bash
# Verify SSH version supports Include (7.3+)
ssh -V

# Test config syntax
ssh -G localhost

# Check if symlink is valid
[[ -L ~/.ssh/config ]] && readlink -f ~/.ssh/config
```

## 📚 Resources

- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [GNU Stow Guide](https://www.gnu.org/software/stow/manual/stow.html)
- [Dotfiles Guide](https://dotfiles.github.io/)

## ✨ Features

- ✅ **Flexible Installation**: Choose copy or symlink mode
- ✅ **Manifest-Based Uninstall**: Precise, clean removal
- ✅ **Cross-Platform**: macOS, Linux, WSL, BSD
- ✅ **Safe**: Always creates timestamped backups
- ✅ **Smart**: Auto-detects OS, enables appropriate configs
- ✅ **Validated**: Checks syntax after installation
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Method Switching**: Easy migration between copy/symlink
