# WSL Vibecoding Setup Skill

[English](README.md) | [中文](README.zh-CN.md)

Agent skill for setting up a Windows 10/11 WSL 2 Ubuntu development environment for AI-assisted coding workflows.

This skill helps an agent plan, automate, or guide:

- WSL installation and version checks
- Ubuntu installation and first-launch account setup
- WSL mirrored networking and connectivity tests
- Node.js, npm, and npm registry mirror setup
- Agent CLI selection: OpenCode, Codex CLI, or Claude Code
- VS Code Remote - WSL setup
- Linux-native project directory recommendations
- Desktop launcher generation for quickly entering the WSL environment

## Contents

```text
wsl-vibecoding-setup/
  SKILL.md
  agents/openai.yaml
  references/
    manual-guidance.md
    research-notes.md
    troubleshooting.md
  scripts/
    Install-WslVibecoding.ps1
    bootstrap-ubuntu-vibecoding.sh
```

## Install The Skill

Clone this repository into your agent skills directory. For agents that support the Codex-compatible skill layout, use:

```powershell
mkdir "$env:USERPROFILE\.codex\skills" -Force
git clone https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git "$env:USERPROFILE\.codex\skills\wsl-vibecoding-setup"
```

If you already cloned it elsewhere, copy the folder:

```powershell
Copy-Item -Recurse -Force . "$env:USERPROFILE\.codex\skills\wsl-vibecoding-setup"
```

Restart your agent or start a new thread/session so the skill list refreshes. You can then invoke it with:

```text
Use $wsl-vibecoding-setup to configure my Windows WSL Ubuntu vibecoding environment.
```

## Install With An Agent

Give this prompt to any terminal-capable coding agent:

```text
Install the agent skill from https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git into my local agent skills directory.
If my agent uses the Codex-compatible skill layout, clone it to %USERPROFILE%\.codex\skills\wsl-vibecoding-setup on Windows, or ~/.codex/skills/wsl-vibecoding-setup on macOS/Linux.
If my agent uses another skills/plugins directory, use that configured directory instead.
After cloning, verify that SKILL.md exists and tell me how to invoke the skill.
```

For an already-cloned repository, ask the agent:

```text
Install this repository as an agent skill by copying the repository root to my agent skills directory as wsl-vibecoding-setup. Do not copy only SKILL.md; preserve agents/, references/, and scripts/.
```

Expected result:

```text
~/.codex/skills/wsl-vibecoding-setup/SKILL.md
~/.codex/skills/wsl-vibecoding-setup/agents/openai.yaml
~/.codex/skills/wsl-vibecoding-setup/references/
~/.codex/skills/wsl-vibecoding-setup/scripts/
```

## Automated Setup

From an elevated PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04
```

The script checks WSL, installs Ubuntu when needed, configures mirrored WSL networking, installs the VS Code Remote - WSL extension when `code` is available, runs the Ubuntu bootstrap script, and creates a Desktop launcher.

Choose agent CLIs explicitly:

```powershell
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli opencode,codex
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli claude
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli none
```

Useful options:

```powershell
.\scripts\Install-WslVibecoding.ps1 -NpmRegistry https://registry.npmmirror.com
.\scripts\Install-WslVibecoding.ps1 -SkipWslMirrorConfig
.\scripts\Install-WslVibecoding.ps1 -SkipNetworkTest
.\scripts\Install-WslVibecoding.ps1 -DryRun
```

## Ubuntu-Only Bootstrap

Inside Ubuntu:

```bash
bash scripts/bootstrap-ubuntu-vibecoding.sh \
  --node-version 24 \
  --project-dir ~/code \
  --npm-registry https://registry.npmmirror.com \
  --install-opencode \
  --install-codex \
  --install-claude
```

The bootstrap installs common developer tools, nvm, Node.js, npm mirror configuration, optional GitHub CLI, optional AI agent CLIs, and a `vibecoding-health` helper.

## Manual Steps The Agent Should Guide

Some steps cannot be safely automated by an agent:

- BIOS/UEFI virtualization settings
- UAC approval and Administrator PowerShell
- First Ubuntu username and password creation
- Browser/device login for GitHub, Codex, OpenCode, or Claude
- Secret and API key handling
- User-specific proxy or mirror choices

When automation cannot proceed, the skill tells the agent to provide exact commands, success criteria, and the output the user should send back.

## Recommended Project Location

Keep active projects inside the WSL filesystem:

```bash
mkdir -p ~/code
cd ~/code
```

Avoid running package managers, tests, or file watchers from `/mnt/c/...` unless you specifically need Windows filesystem access.

## Validation

From Windows:

```powershell
wsl.exe --status
wsl.exe --list --verbose
wsl.exe -d Ubuntu-24.04 -- bash -lc 'uname -a; git --version; node -v; npm -v; npm config get registry'
```

Inside Ubuntu:

```bash
vibecoding-health
```

## Chinese README

See [README.zh-CN.md](README.zh-CN.md).
