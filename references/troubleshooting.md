# Troubleshooting

Use this reference when setup fails or a user asks why WSL/Ubuntu/AI CLIs are not working.

## WSL Install Stops or Hangs

- Confirm Windows version: `winver` or PowerShell `[Environment]::OSVersion.Version`.
- Confirm virtualization is enabled in BIOS/UEFI and Windows features can be enabled.
- Run PowerShell as Administrator for WSL feature installation.
- Try `wsl --update`, then `wsl --shutdown`, then rerun installation.
- If `wsl --install` hangs while downloading a distro, try `wsl --install --web-download -d Ubuntu-24.04`.
- If installation says reboot is required, reboot before continuing.

## Ubuntu Is Installed but Automation Fails

- Launch Ubuntu once from the Start Menu and create the Linux username/password.
- Verify the distro name with `wsl -l -v`; pass that exact name to `-Distro`.
- Run `wsl -d <Distro> -- bash -lc "id -un && uname -a"` to confirm the default Linux user works.
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

## Authentication Issues

- Do not debug by printing secrets.
- Use `codex` for interactive Codex sign-in.
- Use `claude` or `claude doctor` for Claude Code auth and health checks.
- Use `gh auth login` for GitHub authentication.
