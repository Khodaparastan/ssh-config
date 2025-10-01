# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-01

### Added

- **Dual installation modes**: Copy mode (default) and Symlink mode
- **Manifest-based tracking**: `.dotfiles_manifest` for precise installation/uninstall
- **Enhanced installer**: Support for `--method`, `--symlink`, `--force`, `--dry-run`, `--uninstall`, `--quiet` flags
- **Platform detection**: Automatic OS detection with platform-specific config handling
- **Modular configuration**: Split configs by purpose (global, platform, environment, patterns)
- **Security-focused defaults**: Modern cryptography, strict host checking, key-only auth patterns
- **Connection multiplexing**: Automatic socket-based connection reuse
- **Environment-based patterns**: Auto-config for dev/staging/production hosts
- **Jump host patterns**: Bastion/proxy server configurations
- **Git platform configs**: Pre-configured for GitHub, GitLab, Bitbucket
- **Cloudflare tunnel support**: Ready for cloudflared proxy configurations
- **Comprehensive documentation**: Detailed README with examples and troubleshooting

### Features

- Cross-platform support (macOS, Linux, WSL, BSD)
- Automatic backup of existing configurations with timestamps
- SSH config syntax validation after installation
- Secure file permissions (700 for directories, 600 for files)
- Smart handling of symlinks in both installation modes
- Platform-specific configs auto-enabled based on OS detection
- Clean uninstallation with manifest tracking

### Security

- Modern cryptographic algorithm preferences (Ed25519, ChaCha20-Poly1305)
- Environment-based security policies (stricter for production)
- No password authentication for production by default
- Agent forwarding disabled by default (enabled per-host)
- HashKnownHosts enabled globally
- IdentitiesOnly to prevent key exposure

### Documentation

- Installation method comparison and decision guide
- Switching between copy and symlink modes
- Integration guides for GNU Stow, Chezmoi, YADM
- Troubleshooting section for common issues
- Security considerations for both installation modes
- Usage examples for different scenarios
