# Troubleshooting

Use this reference when setup fails or a user asks why WSL/Ubuntu/AI CLIs are not working.

## WSL Install Stops or Hangs

- Confirm Windows version: `winver` or PowerShell `[Environment]::OSVersion.Version`.
- Confirm virtualization is enabled in BIOS/UEFI and Windows features can be enabled.
- Run PowerShell as Administrator for WSL feature installation.
- Prefer running `wsl --install -d Ubuntu-24.04` in a visible PowerShell window. Long silent downloads can be normal; do not start a second install just because there is no output.
- If there has been no output for several minutes, first run `wsl --list --verbose`. If the distro appears as `Running` or `Stopped`, continue to first launch instead of reinstalling.
- Try `wsl --update`, then `wsl --shutdown`, then rerun installation.
- If `wsl --install` hangs while downloading a distro, try `wsl --install --web-download -d Ubuntu-24.04`.
- If installation says reboot is required, reboot before continuing.
- `ERROR_ALREADY_EXISTS` often means another install already registered the distro. Check `wsl --list --verbose`, then run the next stage against the existing distro.

## Interrupted or Duplicate Runs

- Before rerunning, inspect stale setup processes:

```powershell
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -like '*Install-WslVibecoding.ps1*' -or
  $_.CommandLine -like '*bootstrap-ubuntu-vibecoding*'
}
```

- Do not stop processes automatically. Ask the user to confirm they are stale, then use `Stop-Process -Id <pid> -Force`.
- Re-run the setup script after cleanup. It is designed to re-check distro state and skip completed stages.

## Ubuntu Is Installed but Automation Fails

- Launch Ubuntu once from the Start Menu and create the Linux username/password.
- Verify the distro name with `wsl -l -v`; pass that exact name to `-Distro`.
- Run `wsl -d <Distro> -- bash -lc "id -un && uname -a"` to confirm the default Linux user works.
- If `id -un` prints `root`, create a normal user with `adduser`, add it to `sudo`, write `/etc/wsl.conf` with `[user] default=<name>`, run `wsl --shutdown`, and verify again.
- If apt locks exist, wait for unattended upgrades or run `sudo dpkg --configure -a` after checking no apt process is active.

## Slow Repos or Watchers

- Move projects from `/mnt/c/...` to `~/code/...`.
- Open from WSL using `code .`, not from Windows Explorer when Linux tools will run.
- Keep dependency directories (`node_modules`, `.venv`, build caches) inside WSL.

## VS Code Remote WSL Problems

- Install VS Code on Windows, not inside Ubuntu.
- Install the `ms-vscode-remote.remote-wsl` extension on Windows.
- From Ubuntu, run `code .`; the first run installs VS Code Server in WSL.
- If `code` is missing, open VS Code on Windows and use "Shell Command: Install 'code' command in PATH" if available, or reinstall VS Code with PATH integration.

## Codex or Claude Command Missing

- Open a new Ubuntu shell after installing.
- Check `~/.local/bin`, `~/.npm-global/bin`, and nvm paths if using npm-based installs.
- For Codex standalone installs, rerun the official installer or install with `npm install -g @openai/codex` after Node is ready.
- For Claude Code, prefer the official Linux/WSL installer. If using npm, ensure Node.js 18+ and optional dependencies are enabled.

## Node or npm Uses a Windows Path

- Run `command -v node` and `command -v npm`.
- If either command resolves to `/mnt/c/...`, `/mnt/d/...`, or another mounted Windows path, WSL is inheriting Windows PATH before nvm.
- Source nvm before installing CLIs:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm use default
hash -r
command -v node
command -v npm
```

- If the mounted path still wins, adjust `~/.bashrc` or `/etc/wsl.conf` PATH behavior before continuing.

## Authentication Issues

- Do not debug by printing secrets.
- Use `codex` for interactive Codex sign-in.
- Use `claude` or `claude doctor` for Claude Code auth and health checks.
- Use `gh auth login` for GitHub authentication.
