---
name: wsl-vibecoding-setup
description: Build, audit, or automate a Windows 10/11 WSL 2 Ubuntu development environment for AI-assisted "vibecoding" workflows. Use when Codex is asked to install or configure WSL, Ubuntu, WSL mirrored networking, Ubuntu/apt/npm mirrors, VS Code/Cursor Remote WSL, Git, Node/nvm, GitHub CLI, OpenCode CLI, Codex CLI, Claude Code, desktop launchers, credentials guidance, or Linux-native project workspaces on Windows.
---

# WSL Vibecoding Setup

## Core Workflow

Use this skill to turn a Windows machine into a Linux-native coding environment for AI coding agents. Prefer WSL 2 with Ubuntu 24.04 LTS unless the user names another distro.

## Required Flow Split

Structure setup plans around these six stages:

1. **WSL installation**: check whether `wsl.exe` exists, print `wsl --status`, `wsl --version` when available, and `wsl --list --verbose`; install WSL only when missing or unusable; download/install Ubuntu; guide first-launch Linux username/password creation; configure `%UserProfile%\.wslconfig` with mirrored networking when appropriate; run curl connectivity tests.
2. **Node.js and mirrors**: install base Ubuntu packages, nvm, Node.js, npm, and configure an npm registry mirror such as `https://registry.npmmirror.com` unless the user opts out or provides another registry.
3. **Agent CLI selection**: ask which agent CLI to install when the user has not specified one. Offer exactly these choices: `opencode`, `codex`, `claude`; allow multiple choices or `none`. Never install an agent CLI silently.
4. **VS Code guidance**: install or guide installation of the VS Code Remote - WSL extension so VS Code can open files inside WSL. Mention Cursor only as an equivalent editor path when the user uses Cursor.
5. **Project location recommendation**: recommend keeping projects under the WSL filesystem, for example `~/code`, and avoid active development under `/mnt/c` or other Windows-mounted paths.
6. **Desktop launcher**: generate or guide the user to generate a Desktop launcher script that opens the chosen Ubuntu distro directly, so double-clicking enters the environment.

1. Classify the request:
   - For implementation, use `scripts/Install-WslVibecoding.ps1` from elevated PowerShell when WSL, Ubuntu, `.wslconfig`, mirrors, agent CLIs, VS Code extension, or the Desktop launcher might need setup.
   - For Ubuntu-only setup, run `scripts/bootstrap-ubuntu-vibecoding.sh` inside the target Ubuntu distro.
   - For user-run steps or missing permissions, read `references/manual-guidance.md` and provide exact commands plus success criteria.
   - For research, rollout notes, or training material, read `references/research-notes.md`.
   - For failures, read `references/troubleshooting.md`.
2. Check permission boundaries before acting. Codex usually cannot change BIOS/UEFI virtualization, approve UAC, complete Microsoft Store GUI actions, create the first Ubuntu user, finish browser logins, or handle secrets. For those steps, guide the user instead of pretending they are automatable.
3. Keep project files in the Linux filesystem, for example `~/code/project`, not `/mnt/c/...`, when Linux tools or AI agents will run tests, package managers, or file watchers.
4. Never put API keys or login tokens into setup scripts. Install CLIs, then let the user authenticate interactively with `opencode`, `codex`, `claude`, `gh auth login`, or provider-specific flows.
5. Treat WSL install as a two-phase process: Windows feature/distro installation may require a reboot; first Ubuntu launch may require creating the Linux user before automation can continue.

## Automated Setup

From elevated PowerShell on Windows:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04
```

The script prompts for agent CLI choices when none are passed. Useful non-interactive variants:

```powershell
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli opencode,codex
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli none
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -NpmRegistry https://registry.npmmirror.com
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -SkipWslMirrorConfig -SkipNetworkTest
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -DryRun
```

If the script stops after installing WSL or Ubuntu, restart Windows if requested, open Ubuntu once from Start Menu to create the Linux username/password, then rerun the script.

## Ubuntu Bootstrap Only

Inside Ubuntu:

```bash
bash scripts/bootstrap-ubuntu-vibecoding.sh --node-version 24 --project-dir ~/code --npm-registry https://registry.npmmirror.com --install-opencode --install-codex --install-claude
```

The bootstrap installs base developer packages, Git helpers, `ripgrep`, `fd`, `fzf`, `jq`, Python tooling, nvm, Node.js, npm mirror config, curl network tests, and selected AI/hosting CLIs.

## Manual Handoff

When Codex lacks permission or the step is GUI/auth based, give the user a short handoff:

```text
I cannot complete this step directly because <reason>.
Please run/open: <command or GUI path>.
Success looks like: <observable output>.
Then send me: <output or next error>.
```

Always use `references/manual-guidance.md` for BIOS virtualization, Administrator PowerShell, Windows feature enablement, first Ubuntu launch, WSL Settings mirrored networking, curl tests, editor PATH setup, npm/proxy setup, AI CLI selection/login, and Desktop launcher creation.

## Validation

After setup, verify:

```bash
wsl.exe --list --verbose
wsl.exe -d Ubuntu-24.04 -- bash -lc 'uname -a; git --version; node -v; npm -v; npm config get registry'
```

Inside Ubuntu:

```bash
cd ~/code
git --version
node -v
npm -v
npm config get registry
rg --version
opencode --version 2>/dev/null || true
codex --version 2>/dev/null || true
claude --version 2>/dev/null || true
gh --version 2>/dev/null || true
code . 2>/dev/null || true
cursor . 2>/dev/null || true
```

If `code .` fails, install VS Code on Windows and the Remote - WSL extension, then reopen the Ubuntu terminal. If the Desktop launcher fails, verify the distro name with `wsl -l -v` and regenerate the launcher for that exact name.

## Update Guidance

Before hard-coding external installer URLs in new automation, quickly re-check the official docs linked in `references/research-notes.md`. WSL commands are stable, but AI coding CLIs release frequently.
