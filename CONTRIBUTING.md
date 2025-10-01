# Contributing to SSH Config

Thank you for considering contributing to this SSH configuration project! This document provides guidelines for contributing.

## 🤝 How to Contribute

### Reporting Issues

1. Check if the issue already exists in the issue tracker
2. Provide clear description of the problem
3. Include your OS/platform (macOS, Linux, WSL, BSD)
4. Include SSH version: `ssh -V`
5. Include relevant parts of your config (sanitized)

### Suggesting Features

1. Check if the feature has already been requested
2. Describe the use case and benefits
3. Consider backward compatibility
4. Provide examples of how it would work

### Submitting Pull Requests

1. **Fork the repository** and create a feature branch

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following these guidelines:
   - Keep changes focused and atomic
   - Follow existing code style
   - Test on multiple platforms if possible
   - Update documentation as needed

3. **Test your changes**:

   ```bash
   # Test copy mode
   ./install.sh --dry-run
   ./install.sh --force

   # Test symlink mode
   ./install.sh --uninstall
   ./install.sh --symlink --force

   # Validate SSH config syntax
   ssh -G localhost >/dev/null && echo "Valid" || echo "Invalid"
   ```

4. **Commit your changes** with clear messages:

   ```bash
   git commit -m "feat: add support for XYZ"
   git commit -m "fix: resolve issue with ABC on macOS"
   git commit -m "docs: improve installation instructions"
   ```

5. **Push and create a Pull Request**:

   ```bash
   git push origin feature/your-feature-name
   ```

## 📋 Guidelines

### Configuration Files (`config.d/*.conf`)

- Use clear, descriptive comments
- Follow the numbering scheme:
  - `00-09`: Global defaults
  - `01-09`: Platform-specific
  - `10-19`: Shared patterns
  - `50-79`: Custom user configs
  - `80-89`: Special patterns (tunnels, relays)
  - `90-98`: Examples and templates
  - `99`: Catch-all examples

- Security first:
  - Default to secure settings
  - Use modern cryptography
  - Disable risky features by default
  - Document any security trade-offs

### Install Script (`install.sh`)

- Maintain POSIX compatibility where possible
- Add comprehensive error handling
- Provide informative logging
- Test on: macOS, Ubuntu, Debian, Fedora, WSL
- Preserve existing functionality when adding features

### Documentation

- Keep README.md up to date
- Add examples for new features
- Update CHANGELOG.md
- Use clear, concise language
- Include troubleshooting for common issues

## 🧪 Testing Checklist

Before submitting a PR, verify:

- [ ] Works on macOS
- [ ] Works on Linux (Ubuntu/Debian)
- [ ] Works on Linux (Fedora/RHEL)
- [ ] Works on WSL (if applicable)
- [ ] Copy mode works correctly
- [ ] Symlink mode works correctly
- [ ] Uninstall works correctly
- [ ] Dry-run mode works correctly
- [ ] SSH config syntax is valid
- [ ] Backups are created properly
- [ ] Permissions are set correctly (700/600)
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated

## 🔧 Development Setup

```bash
# Clone the repository
git clone https://github.com/khodaparastan/ssh-config.git
cd ssh-config

# Test locally (dry-run)
./install.sh --dry-run

# Test actual installation (symlink mode for development)
./install.sh --symlink --force

# Make changes to configs
vim config.d/00-global-defaults.conf

# Test your changes
ssh -G test-host

# When satisfied, uninstall and test clean install
./install.sh --uninstall
./install.sh --force
```

## 📝 Commit Message Convention

We follow conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Code style changes (formatting)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

Examples:

```text
feat: add support for ProxyJump in bastion pattern
fix: resolve broken symlinks on BSD systems
docs: clarify installation method differences
```

## 🚀 Release Process

Maintainers will:

1. Update version in `install.sh` (installer_version)
2. Update CHANGELOG.md
3. Create git tag: `git tag -a v2.x.x -m "Release v2.x.x"`
4. Push tag: `git push origin v2.x.x`
5. Create GitHub release

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

- Open an issue for questions
- Tag it with `question` label
- Check existing issues first

## 🙏 Thank You

Your contributions help make SSH configuration management better for everyone!
