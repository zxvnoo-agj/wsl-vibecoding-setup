[CmdletBinding()]
param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$NodeVersion = "24",
    [string]$ProjectDir = "~/code",
    [string[]]$AgentCli = @(),
    [string]$NpmRegistry = "https://registry.npmmirror.com",
    [string]$LauncherName = "Vibecoding Ubuntu.cmd",
    [switch]$InstallOpenCode,
    [switch]$InstallCodex,
    [switch]$InstallClaude,
    [switch]$InstallGitHubCli,
    [switch]$NoWslInstall,
    [switch]$SkipWslMirrorConfig,
    [switch]$SkipNpmMirror,
    [switch]$SkipNetworkTest,
    [switch]$SkipVsCodeExtension,
    [switch]$SkipDesktopLauncher,
    [switch]$UseCurrentWindowForWslInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Logged {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $display = "$FilePath $($Arguments -join ' ')"
    if ($DryRun) {
        Write-Host "[dry-run] $display"
        return
    }

    Write-Host $display -ForegroundColor DarkGray
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $display"
    }
}

function Quote-BashArg {
    param([string]$Value)
    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Get-WslDistros {
    if ($DryRun) {
        return @()
    }

    try {
        return @((& wsl.exe --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    catch {
        return @()
    }
}

function Test-WslDistroInstalled {
    param([string]$TargetDistro)
    $distros = Get-WslDistros
    return ($distros -contains $TargetDistro)
}

function Show-ResidualSetupProcesses {
    Write-Step "Checking for leftover setup processes"

    if ($DryRun) {
        Write-Host "[dry-run] inspect Win32_Process for Install-WslVibecoding.ps1 or bootstrap-ubuntu-vibecoding"
        return
    }

    $matches = @(Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $PID -and
        $_.CommandLine -and (
            $_.CommandLine -like "*Install-WslVibecoding.ps1*" -or
            $_.CommandLine -like "*bootstrap-ubuntu-vibecoding*"
        )
    })

    if ($matches.Count -eq 0) {
        Write-Host "No leftover setup processes found."
        return
    }

    Write-Warning "Found possible leftover setup processes. Do not start another WSL install until these are understood."
    $matches | Select-Object ProcessId, Name, CommandLine | Format-List

    $answer = Read-Host "Stop these leftover setup processes? Type YES to stop, or press Enter to leave them running"
    if ($answer -eq "YES") {
        foreach ($process in $matches) {
            Stop-Process -Id $process.ProcessId -Force
            Write-Host "Stopped process $($process.ProcessId)."
        }
    }
    else {
        Write-Host "Left matching processes running."
    }
}

function Show-WslInfo {
    Write-Step "Checking current WSL installation"
    Invoke-Logged -FilePath "wsl.exe" -Arguments @("--status")

    if ($DryRun) {
        Write-Host "[dry-run] wsl.exe --version"
        Write-Host "[dry-run] wsl.exe --list --verbose"
        return
    }

    & wsl.exe --version
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "This Windows build may use the inbox WSL version that does not support 'wsl --version'."
    }

    & wsl.exe --list --verbose
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Unable to list WSL distros yet. This is expected before the first distro is installed."
    }
}

function Invoke-VisibleWslInstall {
    param([string]$TargetDistro)

    Write-Step "Installing distro $TargetDistro in a visible PowerShell window"
    Write-Host "WSL distro downloads can be silent for several minutes. Watch the visible window and do not start a second install."

    if (Test-WslDistroInstalled -TargetDistro $TargetDistro) {
        Write-Host "$TargetDistro appeared before install started; skipping install."
        return
    }

    if ($DryRun) {
        Write-Host "[dry-run] Start-Process powershell.exe for: wsl.exe --install -d $TargetDistro"
        return
    }

    if ($UseCurrentWindowForWslInstall) {
        Invoke-Logged -FilePath "wsl.exe" -Arguments @("--install", "-d", $TargetDistro)
        return
    }

    $escapedDistro = $TargetDistro.Replace("'", "''")
    $command = @"
`$Host.UI.RawUI.WindowTitle = 'WSL install - $escapedDistro'
Write-Host 'Running visible WSL install. This can be silent while Ubuntu downloads.' -ForegroundColor Cyan
Write-Host 'Command: wsl.exe --install -d $escapedDistro'
& wsl.exe --install -d '$escapedDistro'
`$code = `$LASTEXITCODE
Write-Host ''
Write-Host "wsl.exe exited with code `$code. If Windows requested a reboot, reboot before continuing." -ForegroundColor Yellow
Read-Host 'Press Enter to close this installer window after you have read the output'
exit `$code
"@

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -Wait -PassThru

    if (Test-WslDistroInstalled -TargetDistro $TargetDistro) {
        Write-Host "$TargetDistro is now registered."
        return
    }

    if ($process.ExitCode -eq 0) {
        Write-Warning "The visible installer exited successfully, but $TargetDistro is not listed yet. Reboot if requested, then rerun this script."
    }
    else {
        Write-Warning "The visible installer exited with code $($process.ExitCode). If another install was already running, wait for it or inspect wsl --list --verbose before retrying."
    }

    exit 3
}

function Set-WslMirrorConfig {
    $path = Join-Path $HOME ".wslconfig"
    $desired = [ordered]@{
        networkingMode = "mirrored"
        dnsTunneling = "true"
        autoProxy = "true"
    }

    Write-Step "Configuring WSL mirrored networking in $path"
    if ($DryRun) {
        Write-Host "[dry-run] ensure [wsl2] networkingMode=mirrored dnsTunneling=true autoProxy=true"
        return
    }

    if (Test-Path -LiteralPath $path) {
        $backup = "$path.bak-$(Get-Date -Format yyyyMMddHHmmss)"
        Copy-Item -LiteralPath $path -Destination $backup
        Write-Host "Backed up existing .wslconfig to $backup"
        $lines = @(Get-Content -LiteralPath $path)
    }
    else {
        $lines = @()
    }

    $hasWsl2 = $false
    $inWsl2 = $false
    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            if ($inWsl2) {
                foreach ($key in $desired.Keys) {
                    if (-not $seen.ContainsKey($key)) {
                        $out.Add("$key=$($desired[$key])")
                    }
                }
            }
            $section = $Matches[1]
            $inWsl2 = ($section -ieq "wsl2")
            if ($inWsl2) {
                $hasWsl2 = $true
                $seen = @{}
            }
            $out.Add($line)
            continue
        }

        if ($inWsl2 -and $line -match '^\s*([^#;][^=]+?)\s*=') {
            $key = $Matches[1].Trim()
            if ($desired.Contains($key)) {
                $out.Add("$key=$($desired[$key])")
                $seen[$key] = $true
                continue
            }
        }

        $out.Add($line)
    }

    if ($inWsl2) {
        foreach ($key in $desired.Keys) {
            if (-not $seen.ContainsKey($key)) {
                $out.Add("$key=$($desired[$key])")
            }
        }
    }

    if (-not $hasWsl2) {
        if ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -ne "") {
            $out.Add("")
        }
        $out.Add("[wsl2]")
        foreach ($key in $desired.Keys) {
            $out.Add("$key=$($desired[$key])")
        }
    }

    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($path, $out, $enc)
    Write-Host "Updated .wslconfig. WSL must restart for these settings to apply."
    & wsl.exe --shutdown
}

function Resolve-AgentCliSelection {
    $selected = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $sawNone = $false
    foreach ($rawItem in $AgentCli) {
        foreach ($item in ($rawItem -split ",")) {
            $value = $item.Trim().ToLowerInvariant()
            if (-not $value) { continue }
            if ($value -eq "none") {
                $sawNone = $true
                continue
            }
            if ($value -eq "all") {
                [void]$selected.Add("opencode")
                [void]$selected.Add("codex")
                [void]$selected.Add("claude")
                continue
            }
            if (@("opencode", "codex", "claude") -notcontains $value) {
                throw "Unsupported agent CLI choice: $value"
            }
            [void]$selected.Add($value)
        }
    }
    if ($InstallOpenCode) { [void]$selected.Add("opencode") }
    if ($InstallCodex) { [void]$selected.Add("codex") }
    if ($InstallClaude) { [void]$selected.Add("claude") }

    if ($selected.Count -eq 0 -and -not $sawNone -and -not $DryRun) {
        Write-Host ""
        Write-Host "Select agent CLI(s) to install: opencode, codex, claude, or none."
        $answer = Read-Host "Enter comma-separated choices"
        foreach ($choice in ($answer -split ",")) {
            $value = $choice.Trim().ToLowerInvariant()
            if ($value -eq "" -or $value -eq "none") { continue }
            if (@("opencode", "codex", "claude") -notcontains $value) {
                throw "Unsupported agent CLI choice: $value"
            }
            [void]$selected.Add($value)
        }
    }

    return @($selected)
}

function New-DesktopWslLauncher {
    param([string]$TargetDistro)

    Write-Step "Creating Desktop launcher"
    $desktop = [Environment]::GetFolderPath("DesktopDirectory")
    if (-not $desktop) {
        Write-Warning "Could not locate Desktop directory; skipping launcher."
        return
    }
    $path = Join-Path $desktop $LauncherName
    $content = "@echo off`r`ntitle Vibecoding $TargetDistro`r`nwsl.exe -d $TargetDistro --cd ~`r`nif errorlevel 1 pause`r`n"

    if ($DryRun) {
        Write-Host "[dry-run] write launcher to $path"
        Write-Host $content
        return
    }

    $enc = New-Object System.Text.ASCIIEncoding
    [System.IO.File]::WriteAllText($path, $content, $enc)
    Write-Host "Desktop launcher created: $path"
}

function Assert-ConfiguredLinuxUser {
    param([string]$TargetDistro)

    Write-Step "Checking that $TargetDistro can run as a configured Linux user"

    if ($DryRun) {
        Write-Host "[dry-run] wsl.exe -d $TargetDistro -- bash -lc 'id -un && uname -a'"
        return
    }

    try {
        $user = (& wsl.exe -d $TargetDistro -- bash -lc "id -un").Trim()
        if ($LASTEXITCODE -ne 0 -or -not $user) {
            throw "Ubuntu user check failed."
        }

        & wsl.exe -d $TargetDistro -- bash -lc "uname -a"
        if ($LASTEXITCODE -ne 0) {
            throw "Ubuntu kernel check failed."
        }
    }
    catch {
        Write-Warning "Open $TargetDistro once from the Start Menu, create the Linux username/password, then rerun this script."
        exit 2
    }

    if ($user -eq "root") {
        Write-Warning "$TargetDistro currently starts as root. Create a normal Linux user before running developer tooling."
        Write-Host ""
        Write-Host "Open a visible Ubuntu shell and run:"
        Write-Host "  adduser <your-linux-username>"
        Write-Host "  usermod -aG sudo <your-linux-username>"
        Write-Host "  printf '[user]\ndefault=<your-linux-username>\n' > /etc/wsl.conf"
        Write-Host "Then from Windows run:"
        Write-Host "  wsl.exe --shutdown"
        Write-Host "  wsl.exe -d $TargetDistro -- bash -lc 'id -un && sudo -v'"
        exit 2
    }
}

function Copy-TextIntoWsl {
    param(
        [string]$TargetDistro,
        [string]$Content,
        [string]$RemotePath,
        [switch]$Executable
    )

    $mode = if ($Executable) { "chmod +x $(Quote-BashArg $RemotePath)" } else { "true" }
    $command = "cat > $(Quote-BashArg $RemotePath) && $mode"
    $Content | & wsl.exe -d $TargetDistro -- bash -lc $command
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy content into WSL path: $RemotePath"
    }
}

Write-Step "Checking Windows and WSL prerequisites"
$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19041) {
    throw "WSL install automation requires Windows 10 build 19041+ or Windows 11. Current build: $build"
}

if (-not (Test-Admin) -and -not $NoWslInstall) {
    Write-Warning "Run PowerShell as Administrator if WSL features or the distro still need installation."
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe was not found. Update Windows or enable Windows Subsystem for Linux first."
}

Show-ResidualSetupProcesses
Show-WslInfo

if (-not $NoWslInstall) {
    Write-Step "Ensuring WSL 2 is the default"
    Invoke-Logged -FilePath "wsl.exe" -Arguments @("--set-default-version", "2")

    if (Test-WslDistroInstalled -TargetDistro $Distro) {
        Write-Host "$Distro is already installed."
    }
    else {
        # Recheck immediately before the long-running install to avoid racing another installer.
        if (Test-WslDistroInstalled -TargetDistro $Distro) {
            Write-Host "$Distro appeared during setup; skipping install."
        }
        else {
            Invoke-VisibleWslInstall -TargetDistro $Distro
        }
    }
}

if (-not $SkipWslMirrorConfig) {
    Set-WslMirrorConfig
}

Assert-ConfiguredLinuxUser -TargetDistro $Distro

if (-not $SkipVsCodeExtension) {
    Write-Step "Installing VS Code Remote - WSL extension when code.exe is available"
    $code = Get-Command code.cmd, code.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($code) {
        Invoke-Logged -FilePath $code.Source -Arguments @("--install-extension", "ms-vscode-remote.remote-wsl")
    }
    else {
        Write-Warning "VS Code command 'code' was not found. Install VS Code on Windows, then install the Remote - WSL extension."
    }
}

Write-Step "Running Ubuntu vibecoding bootstrap"
$bootstrapPath = Join-Path $PSScriptRoot "bootstrap-ubuntu-vibecoding.sh"
if (-not (Test-Path -LiteralPath $bootstrapPath)) {
    throw "Missing bootstrap script: $bootstrapPath"
}

$selectedAgents = Resolve-AgentCliSelection

$bootstrapArgs = @("--node-version", $NodeVersion, "--project-dir", $ProjectDir)
if (-not $SkipNpmMirror -and $NpmRegistry) { $bootstrapArgs += @("--npm-registry", $NpmRegistry) }
if ($SkipNpmMirror) { $bootstrapArgs += "--no-npm-mirror" }
if ($SkipNetworkTest) { $bootstrapArgs += "--skip-network-test" }
if ($selectedAgents -contains "opencode") { $bootstrapArgs += "--install-opencode" }
if ($selectedAgents -contains "codex") { $bootstrapArgs += "--install-codex" }
if ($selectedAgents -contains "claude") { $bootstrapArgs += "--install-claude" }
if ($InstallGitHubCli) { $bootstrapArgs += "--install-gh" }

if ($DryRun) {
    Write-Host "[dry-run] copy $bootstrapPath to WSL /tmp/bootstrap-ubuntu-vibecoding.sh"
    Write-Host "[dry-run] create /tmp/run-vibecoding-bootstrap.sh with quoted arguments"
    Write-Host "[dry-run] run: bash /tmp/run-vibecoding-bootstrap.sh"
    if (-not $SkipDesktopLauncher) {
        New-DesktopWslLauncher -TargetDistro $Distro
    }
    exit 0
}

$bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw
Copy-TextIntoWsl -TargetDistro $Distro -Content $bootstrapContent -RemotePath "/tmp/bootstrap-ubuntu-vibecoding.sh" -Executable

$runnerCommand = (@("/tmp/bootstrap-ubuntu-vibecoding.sh") + $bootstrapArgs | ForEach-Object { Quote-BashArg $_ }) -join " "
$runnerContent = "#!/usr/bin/env bash`nset -euo pipefail`n$runnerCommand`n"
Copy-TextIntoWsl -TargetDistro $Distro -Content $runnerContent -RemotePath "/tmp/run-vibecoding-bootstrap.sh" -Executable

$bootstrapSucceeded = $true
try {
    Invoke-Logged -FilePath "wsl.exe" -Arguments @("-d", $Distro, "--", "bash", "/tmp/run-vibecoding-bootstrap.sh")
}
catch {
    $bootstrapSucceeded = $false
    Write-Warning $_.Exception.Message
    Write-Warning "Base WSL setup may still be usable. Fix the reported stage, then rerun this script; completed stages are idempotent."
}

if (-not $SkipDesktopLauncher) {
    New-DesktopWslLauncher -TargetDistro $Distro
}

Write-Step "Final healthcheck"
& wsl.exe -d $Distro -- bash -lc '$HOME/.config/vibecoding/healthcheck.sh 2>/dev/null || true'

Write-Step "Done"
Write-Host "Open Ubuntu and run: cd $ProjectDir"
Write-Host "Run interactive logins as needed: opencode, codex, claude, gh auth login"

if (-not $bootstrapSucceeded) {
    exit 4
}
