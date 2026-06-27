# WSL Vibecoding Setup Skill

[English](README.md) | [中文](README.zh-CN.md)

这是一个 Agent skill，用于在 Windows 10/11 上配置面向 AI 辅助编程的 WSL 2 + Ubuntu 开发环境。

它可以帮助 Agent 自动化或引导完成：

- WSL 安装检查与版本检查
- Ubuntu 下载、安装与首次账号密码设置
- 长时间静默的 WSL/Ubuntu 安装可见窗口交接
- WSL mirrored networking 配置与 curl 连通性测试
- Node.js、npm 与 npm mirror 配置
- Agent CLI 选择安装：OpenCode、Codex CLI 或 Claude Code
- 中断恢复、幂等重跑、root 默认用户修复指引和最终健康检查
- VS Code Remote - WSL 插件配置提示
- 建议项目文件放在 WSL 文件系统中
- 在桌面生成一键进入 WSL 环境的启动脚本

## 目录结构

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

## 安装 Skill

将仓库克隆到你的 Agent skills 目录。对于支持 Codex-compatible skill 布局的 Agent，可以使用：

```powershell
mkdir "$env:USERPROFILE\.codex\skills" -Force
git clone https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git "$env:USERPROFILE\.codex\skills\wsl-vibecoding-setup"
```

如果你的 Agent 使用其他 skills/plugins 目录，请克隆到该 Agent 配置的目录，并保持目录名为 `wsl-vibecoding-setup`。

如果仓库已经下载到本地，也可以直接复制整个目录：

```powershell
Copy-Item -Recurse -Force . "$env:USERPROFILE\.codex\skills\wsl-vibecoding-setup"
```

然后重启你的 Agent，或开启一个新线程/会话，让 skill 列表刷新。之后可以这样调用：

```text
Use $wsl-vibecoding-setup to configure my Windows WSL Ubuntu vibecoding environment.
```

## 给 Agent 的安装方式

可以把下面这段提示词交给任意能够操作终端的编程 Agent：

```text
请把 https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git 安装为本机 Agent skill。
如果我的 Agent 使用 Codex-compatible skill 布局，请在 Windows 上克隆到 %USERPROFILE%\.codex\skills\wsl-vibecoding-setup，或在 macOS/Linux 上克隆到 ~/.codex/skills/wsl-vibecoding-setup。
如果我的 Agent 使用其他 skills/plugins 目录，请使用该 Agent 配置的目录。
克隆后请确认 SKILL.md 存在，并告诉我如何调用这个 skill。
```

如果仓库已经下载到本地，可以让 Agent 使用：

```text
请把当前仓库根目录复制到我的 Agent skills 目录，并命名为 wsl-vibecoding-setup。不要只复制 SKILL.md；必须保留 agents/、references/ 和 scripts/ 目录。
```

安装完成后应看到：

```text
~/.codex/skills/wsl-vibecoding-setup/SKILL.md
~/.codex/skills/wsl-vibecoding-setup/agents/openai.yaml
~/.codex/skills/wsl-vibecoding-setup/references/
~/.codex/skills/wsl-vibecoding-setup/scripts/
```

如果你的 Agent 使用其他 skills/plugins 目录，上面的 `.codex/skills` 路径应替换为该 Agent 的实际配置路径。

## 自动化配置

在管理员 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04
```

脚本会检查 WSL、按需安装 Ubuntu、配置 WSL mirrored networking、在检测到 VS Code 时安装 Remote - WSL 插件、运行 Ubuntu bootstrap，并在桌面生成启动脚本。

涉及 `wsl --install` 时，脚本默认打开一个可见 PowerShell 安装窗口。Ubuntu 下载可能长时间没有输出，这是正常情况；请观察该窗口，不要因为静默就启动第二个安装。

明确选择要安装的 Agent CLI：

```powershell
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli opencode,codex
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli claude
.\scripts\Install-WslVibecoding.ps1 -Distro Ubuntu-24.04 -AgentCli none
```

常用选项：

```powershell
.\scripts\Install-WslVibecoding.ps1 -NpmRegistry https://registry.npmmirror.com
.\scripts\Install-WslVibecoding.ps1 -SkipWslMirrorConfig
.\scripts\Install-WslVibecoding.ps1 -SkipNetworkTest
.\scripts\Install-WslVibecoding.ps1 -DryRun
```

## 仅配置 Ubuntu

如果 Ubuntu 已经安装好，可以在 Ubuntu 内运行：

```bash
bash scripts/bootstrap-ubuntu-vibecoding.sh \
  --node-version 24 \
  --project-dir ~/code \
  --npm-registry https://registry.npmmirror.com \
  --install-opencode \
  --install-codex \
  --install-claude
```

该脚本会安装常用开发工具、nvm、Node.js、npm mirror、可选 GitHub CLI、可选 AI Agent CLI，并生成 `vibecoding-health` 健康检查命令。

可选 Agent CLI 被拆成独立阶段。如果某个 CLI 安装失败，基础环境仍可能已经完成，可以修复网络或安装器问题后单独重试。Codex CLI 的 standalone installer 失败时，会在 npm 可用的情况下 fallback 到 `npm install -g @openai/codex`。

## 需要用户手动完成的步骤

以下步骤通常不能由 Agent 直接完成，skill 会引导用户操作：

- BIOS/UEFI 中开启虚拟化
- UAC 授权与管理员 PowerShell
- Ubuntu 首次启动时创建用户名和密码
- GitHub、Codex CLI、OpenCode、Claude Code 的浏览器或设备码登录
- 密钥、Token、API Key 等敏感信息处理
- 用户自己的代理和镜像源选择
- 用户中断后确认并停止残留安装进程

当 Agent 没有权限继续时，它应该给出明确命令、成功标准，以及需要用户返回的输出或错误信息。

## 项目文件位置建议

建议把项目放在 WSL 文件系统中：

```bash
mkdir -p ~/code
cd ~/code
```

不要把需要频繁运行包管理器、测试、文件监听器的项目放在 `/mnt/c/...`，除非你明确需要访问 Windows 文件系统。

## 验证方式

从 Windows 运行：

```powershell
wsl.exe --status
wsl.exe --list --verbose
wsl.exe -d Ubuntu-24.04 -- bash -lc 'id -un; git --version; node -v; npm -v; npm config get registry; rg --version | head -n 1; command -v codex || true; codex --version 2>/dev/null || true; ls -ld ~/code'
```

在 Ubuntu 中运行：

```bash
vibecoding-health
```

健康检查会打印 Linux 用户名、Git/Node/npm/ripgrep 版本、npm registry、所选 CLI 版本、`command -v codex`、Node/npm 路径和 `~/code` 状态。

## 英文 README

See [README.md](README.md).
