# Research Notes

Use this reference when producing setup plans, checklists, or user-facing docs for Windows WSL Ubuntu vibecoding environments.

## Source Baseline

- Microsoft WSL install docs: `https://learn.microsoft.com/en-us/windows/wsl/install`
- Microsoft WSL development environment docs: `https://learn.microsoft.com/en-us/windows/wsl/setup/environment`
- Ubuntu on WSL install docs: `https://documentation.ubuntu.com/wsl/latest/howto/install-ubuntu-wsl2/`
- VS Code Remote WSL docs: `https://code.visualstudio.com/docs/remote/wsl`
- Microsoft WSL config docs: `https://learn.microsoft.com/en-us/windows/wsl/wsl-config`
- OpenCode docs: `https://opencode.ai/docs/`
- OpenAI Codex CLI docs: `https://developers.openai.com/codex/cli`
- OpenAI Codex GitHub README: `https://github.com/openai/codex`
- Claude Code setup docs: `https://code.claude.com/docs/en/setup`
- nvm README: `https://github.com/nvm-sh/nvm`
- GitHub CLI Linux install docs: `https://github.com/cli/cli/blob/trunk/docs/install_linux.md`

## Current Installation Shape

- Windows requirement: Microsoft documents `wsl --install` for Windows 10 version 2004 / build 19041 or later, and Windows 11. Ubuntu's WSL guide recommends Windows 11 or Windows 10 21H2 or later.
- Default path: run `wsl --install`, reboot if prompted, launch Ubuntu, create the Linux username/password, then run Linux bootstrap automation.
- Specific distro: use `wsl --list --online`, then `wsl --install -d Ubuntu-24.04` or another listed distro.
- WSL version: new installs from `wsl --install` are WSL 2 by default on current Windows builds. Verify with `wsl -l -v`.
- File placement: put Linux-tool projects in the WSL filesystem, such as `\\wsl$\Ubuntu-24.04\home\<user>\code` or `~/code`, not under `/mnt/c`, when performance matters.
- Editor path: install VS Code on Windows plus the Remote - WSL extension, then open a WSL project with `code .`.
- WSL mirrored networking: use `%UserProfile%\.wslconfig` `[wsl2]` keys such as `networkingMode=mirrored`, `dnsTunneling=true`, and `autoProxy=true` when supported by the user's WSL/Windows build; run `wsl --shutdown` after edits.

## Vibecoding Tooling Stack

Minimum useful stack:

- Ubuntu packages: `build-essential`, `git`, `curl`, `wget`, `ca-certificates`, `gnupg`, `jq`, `ripgrep`, `fd-find`, `fzf`, `unzip`, `zip`, `python3`, `python3-pip`, `pipx`.
- Git config: set `user.name`, `user.email`, and consider `init.defaultBranch main`.
- Node: install with nvm so each project can pin Node in `.nvmrc`. Default this skill to Node 24 unless project requirements say otherwise.
- npm mirror: configure `npm config set registry https://registry.npmmirror.com` when the user wants a mainland China mirror; otherwise use the official registry.
- GitHub CLI: optional but useful for repo auth, issues, PRs, and agent workflows.
- OpenCode CLI: offer as one of the three explicit agent options (`opencode`, `codex`, `claude`).
- Codex CLI: install inside WSL for Linux-native repos; authenticate interactively with ChatGPT or an API key after install.
- Claude Code: install inside WSL when the user wants Claude-based coding agents or sandboxed Linux toolchains; authenticate interactively after install.

## Security and Credentials

- Do not write `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, GitHub tokens, SSH private keys, or browser session material into generated scripts.
- Prefer interactive login commands after install.
- For team rollouts, point users to provider-managed auth and device/browser flows.
- Use SSH keys or GitHub CLI credential flow for Git access, not embedded passwords.

## Manual Recovery Commands

PowerShell:

```powershell
wsl --status
wsl --update
wsl --list --online
wsl --list --verbose
wsl --set-default-version 2
wsl --install -d Ubuntu-24.04
wsl --set-version Ubuntu-24.04 2
wsl --shutdown
```

Ubuntu:

```bash
sudo apt update && sudo apt upgrade -y
mkdir -p ~/code
cd ~/code
explorer.exe .
code .
```

## User-Provided Zhihu Reference

Requested comparison target: `https://zhuanlan.zhihu.com/p/2029583356837275038`.

The article URL returned HTTP 403 to direct fetch attempts, and search did not reveal a reliable cached copy. Do not claim to have read its exact text unless the user provides the article content. For self-checks against this article family, verify that the skill covers these likely Windows-to-WSL vibecoding phases:

- Windows version and virtualization readiness.
- Administrator PowerShell WSL installation.
- Ubuntu distro installation and first launch user creation.
- WSL 2 verification and update commands.
- Linux filesystem project directory such as `~/code`.
- Ubuntu package bootstrap and Git config.
- Node.js via nvm rather than Windows Node for WSL projects.
- VS Code or Cursor installed on Windows and opened from WSL with `code .` or `cursor .`.
- GitHub CLI and interactive authentication.
- Codex CLI / Claude Code installation and interactive authentication.
- Proxy or mirror guidance for networks where GitHub, npm, apt, OpenAI, or Anthropic are slow or blocked.
- Clear user handoff for steps Codex cannot perform directly.
- Desktop launcher generation so the user can double-click into the configured WSL distro.
