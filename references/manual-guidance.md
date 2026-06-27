# Manual Guidance

Use this reference whenever Codex cannot directly complete a step because it requires Windows Administrator approval, BIOS/UEFI changes, GUI login, browser authentication, Microsoft Store, network/proxy choices, or a user secret.

## Permission Boundary Checklist

Guide the user step by step instead of failing silently:

1. Explain why Codex cannot complete the step directly.
2. Give the exact command or GUI path the user should run.
3. Tell the user what success looks like.
4. Ask the user to return with the output, screenshot text, or the next error if it fails.

## Windows Preparation

Ask the user to confirm:

- Windows 10 build 19041+ or Windows 11: run `winver`.
- CPU virtualization is enabled: Task Manager > Performance > CPU > Virtualization, or enable Intel VT-x / AMD-V / SVM in BIOS/UEFI.
- PowerShell is running as Administrator for WSL feature installation.
- Windows is up to date enough to use the modern `wsl --install` command.

Manual admin commands:

```powershell
wsl --status
wsl --version
wsl --list --verbose
wsl --update
wsl --set-default-version 2
wsl --list --online
wsl --install -d Ubuntu-24.04
```

For `wsl --install`, prefer a visible Administrator PowerShell window. Distro downloads can be silent for several minutes. If there is no output but the process/window is still open, do not start a second install. First check:

```powershell
wsl --list --verbose
```

If the distro appears as `Running` or `Stopped`, continue to first launch. If it does not appear, ask the user what the visible installer window shows.

If modern WSL install is unavailable, guide the user to enable Windows features manually:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Then reboot, run `wsl --update`, and install Ubuntu.

## WSL Settings and Network Test

When Codex cannot edit `%UserProfile%\.wslconfig`, ask the user to create or update it:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

Then ask the user to restart WSL:

```powershell
wsl --shutdown
```

After Ubuntu starts, test connectivity:

```bash
curl -I https://github.com
curl -I https://registry.npmmirror.com
curl -I https://opencode.ai
```

If mirrored networking is unsupported on the user's Windows/WSL build, fall back to proxy variables or regional mirrors after asking the user for their proxy or mirror preference.

## Ubuntu First Launch

Codex cannot create the first Linux user if Ubuntu has never been launched. Instruct the user:

1. Open Ubuntu 24.04 from the Start Menu.
2. Wait for installation to finish.
3. Create a lowercase Linux username.
4. Create and remember the Linux password. It is used for `sudo`; typed characters may not appear.
5. Run `whoami` and `pwd`; success should show the username and `/home/<user>`.

Then Codex or the user can run:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "id -un && uname -a"
```

If `id -un` prints `root`, create a normal user and make it the WSL default user:

```bash
adduser <your-linux-username>
usermod -aG sudo <your-linux-username>
printf '[user]\ndefault=<your-linux-username>\n' > /etc/wsl.conf
```

Then from Windows:

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04 -- bash -lc "id -un && sudo -v"
```

Success means `id -un` prints the normal username, not `root`, and `sudo -v` accepts that user's Linux password.

## Editor and WSL Project Flow

Recommended flow:

1. Install VS Code or Cursor on Windows.
2. Install the Remote - WSL extension in that editor when available.
3. Open Ubuntu.
4. Create project space: `mkdir -p ~/code && cd ~/code`.
5. Open the folder from Linux: `code .` for VS Code, or `cursor .` if Cursor exposes a WSL shell command.

If `code .` or `cursor .` fails, tell the user to install the editor on Windows, add it to PATH, reopen Ubuntu, and retry.

## Node.js and npm Mirror

Inside Ubuntu, prefer nvm-managed Node.js. If the user wants a mainland China npm mirror, configure:

```bash
npm config set registry https://registry.npmmirror.com
npm config get registry
```

If the user wants the official registry:

```bash
npm config set registry https://registry.npmjs.org/
```

Do not rewrite project lockfiles just to change mirrors.

After Node setup, check that WSL is not accidentally using Windows Node/npm from a mounted drive:

```bash
command -v node
command -v npm
```

If either path starts with `/mnt/c`, `/mnt/d`, or another `/mnt/*` path, load nvm earlier in `~/.bashrc`, open a new shell, and verify again before installing agent CLIs.

Avoid complex one-line commands that cross PowerShell, `wsl.exe`, and Bash when they contain `$HOME`, `$PATH`, `$NVM_DIR`, `$(...)`, or nested quotes. Generate a temporary `.sh` file inside WSL and run that file instead.

## Network and China Mainland Notes

If downloads from GitHub, npm, OpenAI, Anthropic, or Ubuntu mirrors fail:

- Ask whether the user uses a proxy or VPN and whether it is available inside WSL.
- For WSL, document proxy environment variables only when the user supplies the proxy address:

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7890
```

- Do not hard-code mirror or proxy settings without user confirmation.
- If apt is slow, recommend choosing a regional Ubuntu mirror, then edit `/etc/apt/sources.list.d/ubuntu.sources` or the distro-specific apt source file carefully after backing it up.

## AI CLI Authentication

Never automate secrets. Give interactive steps:

```bash
opencode
gh auth login
codex
claude
```

Tell the user to complete browser/device login prompts. For API-key based tools, ask the user to use a provider-approved secret store or shell profile entry themselves; do not request plaintext keys in chat.

When the user has not chosen an agent CLI, ask exactly:

```text
Which agent CLI do you want to install? Choose one or more: opencode, codex, claude, or none.
```

Use the corresponding installer flag:

```powershell
.\scripts\Install-WslVibecoding.ps1 -AgentCli opencode
.\scripts\Install-WslVibecoding.ps1 -AgentCli codex
.\scripts\Install-WslVibecoding.ps1 -AgentCli claude
.\scripts\Install-WslVibecoding.ps1 -AgentCli opencode,codex
```

## Desktop Launcher

If Codex cannot write to the user's Desktop, ask the user to create `Vibecoding Ubuntu.cmd` on the Desktop with:

```bat
@echo off
title Vibecoding Ubuntu-24.04
wsl.exe -d Ubuntu-24.04 --cd ~
if errorlevel 1 pause
```

Success means double-clicking the file opens an interactive Ubuntu shell in the home directory. If it closes immediately, run `wsl -l -v` and replace `Ubuntu-24.04` with the exact distro name.

## Verification Script for Users

Ask the user to run inside Ubuntu:

```bash
cd ~/code
id -un
git --version
node -v
npm -v
npm config get registry
rg --version | head -n 1
command -v code >/dev/null && code --version | head -n 1 || true
command -v cursor >/dev/null && cursor --version | head -n 1 || true
command -v gh >/dev/null && gh --version | head -n 1 || true
command -v codex || true
command -v opencode >/dev/null && opencode --version || true
command -v codex >/dev/null && codex --version || true
command -v claude >/dev/null && claude --version || true
ls -ld ~/code
```

## Interrupted Run Recovery

If a prior setup run was interrupted, inspect leftover setup processes before rerunning installers:

```powershell
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -like '*Install-WslVibecoding.ps1*' -or
  $_.CommandLine -like '*bootstrap-ubuntu-vibecoding*'
}
```

Only stop matching processes after the user confirms they are stale:

```powershell
Stop-Process -Id <pid> -Force
```
