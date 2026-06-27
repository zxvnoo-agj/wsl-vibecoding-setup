# WSL Vibecoding Setup Skill

[中文](README.md) | [English](README.en.md)

这是一个用于 Windows 10/11 的 Agent skill，帮助 Agent 为用户规划、自动化或引导完成 WSL 2 + Ubuntu 的 AI 辅助编程环境配置。

它适合用于把一台 Windows 电脑整理成更稳定的 Linux-native 开发环境，包括 WSL/Ubuntu、Node.js、npm mirror、常见 Agent CLI、VS Code Remote - WSL、桌面启动脚本和最终健康检查。

## 主要优点

- **流程清晰**：按 WSL 安装、Ubuntu 初始化、Node/npm、Agent CLI、编辑器、项目目录和启动器拆分。
- **更适合人机交接**：遇到 UAC、首次 Ubuntu 用户创建、登录鉴权等 Agent 无法代劳的步骤时，会给出明确指引。
- **可重复执行**：每个关键阶段都会重新判断当前状态，减少重复安装和半途失败后的混乱。
- **更稳的 WSL 安装体验**：长时间的 `wsl --install` 默认使用可见窗口，避免把静默下载误判为卡住。
- **失败可恢复**：可选 CLI 安装失败不会否定基础环境成果，可以从最近成功阶段继续。
- **面向真实开发**：强调项目放在 WSL 文件系统中，检查 Windows PATH 污染，并提供固定健康检查。

## 给 Agent 的安装提示

```text
请把 https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git 安装为本机 Agent skill。
如果我的 Agent 使用 Codex-compatible skill 布局，请在 Windows 上克隆到 %USERPROFILE%\.codex\skills\wsl-vibecoding-setup，或在 macOS/Linux 上克隆到 ~/.codex/skills/wsl-vibecoding-setup。
如果我的 Agent 使用其他 skills/plugins 目录，请使用该 Agent 配置的目录。
克隆后请确认 SKILL.md 存在，并告诉我如何调用这个 skill。
```
