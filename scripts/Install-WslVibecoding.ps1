[CmdletBinding()]
param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$NodeVersion = "24",
    [string]$ProjectDir = "~/code",
    [ValidateSet("opencode", "codex", "claude", "all", "none")]
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
    foreach ($item in $AgentCli) {
        if ($item -eq "all") {
            [void]$selected.Add("opencode")
            [void]$selected.Add("codex")
            [void]$selected.Add("claude")
        }
        elseif ($item -ne "none") {
            [void]$selected.Add($item)
        }
    }
    if ($InstallOpenCode) { [void]$selected.Add("opencode") }
    if ($InstallCodex) { [void]$selected.Add("codex") }
    if ($InstallClaude) { [void]$selected.Add("claude") }

    if ($selected.Count -eq 0 -and ($AgentCli -notcontains "none") -and -not $DryRun) {
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
    $content = "@echo off`r`ntitle Vibecoding $TargetDistro`r`nwsl.exe -d `"$TargetDistro`" --cd ~`r`n"

    if ($DryRun) {
        Write-Host "[dry-run] write launcher to $path"
        Write-Host $content
        return
    }

    $enc = New-Object System.Text.ASCIIEncoding
    [System.IO.File]::WriteAllText($path, $content, $enc)
    Write-Host "Desktop launcher created: $path"
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

Show-WslInfo

if (-not $NoWslInstall) {
    Write-Step "Ensuring WSL 2 is the default"
    Invoke-Logged -FilePath "wsl.exe" -Arguments @("--set-default-version", "2")

    $installedDistros = @()
    if (-not $DryRun) {
        $installedDistros = (& wsl.exe --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if ($DryRun -or ($installedDistros -notcontains $Distro)) {
        Write-Step "Installing distro $Distro if it is not already installed"
        Invoke-Logged -FilePath "wsl.exe" -Arguments @("--install", "-d", $Distro)
        Write-Host "If Windows asks for a reboot, reboot, launch $Distro once, create the Linux user, then rerun this script."
    }
    else {
        Write-Host "$Distro is already installed."
    }
}

if (-not $SkipWslMirrorConfig) {
    Set-WslMirrorConfig
}

Write-Step "Checking that $Distro can run as a configured Linux user"
if (-not $DryRun) {
    try {
        & wsl.exe -d $Distro -- bash -lc "id -un && uname -a"
        if ($LASTEXITCODE -ne 0) {
            throw "Ubuntu user check failed."
        }
    }
    catch {
        Write-Warning "Open $Distro once from the Start Menu, create the Linux username/password, then rerun this script."
        exit 2
    }
}
else {
    Write-Host "[dry-run] wsl.exe -d $Distro -- bash -lc 'id -un && uname -a'"
}

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
    Write-Host "[dry-run] run: /tmp/bootstrap-ubuntu-vibecoding.sh $($bootstrapArgs -join ' ')"
    if (-not $SkipDesktopLauncher) {
        New-DesktopWslLauncher -TargetDistro $Distro
    }
    exit 0
}

$bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw
$bootstrapContent | & wsl.exe -d $Distro -- bash -lc "cat > /tmp/bootstrap-ubuntu-vibecoding.sh && chmod +x /tmp/bootstrap-ubuntu-vibecoding.sh"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to copy bootstrap script into WSL."
}

$quoted = @("/tmp/bootstrap-ubuntu-vibecoding.sh") + $bootstrapArgs | ForEach-Object { Quote-BashArg $_ }
$command = $quoted -join " "
Invoke-Logged -FilePath "wsl.exe" -Arguments @("-d", $Distro, "--", "bash", "-lc", $command)

if (-not $SkipDesktopLauncher) {
    New-DesktopWslLauncher -TargetDistro $Distro
}

Write-Step "Done"
Write-Host "Open Ubuntu and run: cd $ProjectDir"
Write-Host "Run interactive logins as needed: opencode, codex, claude, gh auth login"
