# WSL Vibecoding Setup Skill

[中文](README.md) | [English](README.en.md)

This Agent skill helps an agent plan, automate, or guide the setup of a Windows 10/11 WSL 2 + Ubuntu environment for AI-assisted coding workflows.

It is designed for turning a Windows machine into a stable Linux-native development workspace with WSL/Ubuntu, Node.js, npm mirrors, common Agent CLIs, VS Code Remote - WSL, a desktop launcher, and a final healthcheck.

## Why Use It

- **Clear workflow**: Splits setup into WSL, Ubuntu, Node/npm, Agent CLI, editor, project location, and launcher stages.
- **Better human handoff**: Gives direct guidance for UAC, first Ubuntu user creation, login flows, and other steps an agent cannot safely complete.
- **Rerunnable by design**: Rechecks state before key stages to reduce duplicate installs and confusing partial failures.
- **Safer WSL install experience**: Runs long `wsl --install` work in a visible window so silent downloads are not mistaken for hangs.
- **Recoverable failures**: Optional CLI installer failures do not invalidate the completed base environment.
- **Built for real development**: Encourages WSL filesystem projects, checks Windows PATH pollution, and provides a consistent healthcheck.

## Agent Install Prompt

```text
Install the agent skill from https://github.com/zxvnoo-agj/wsl-vibecoding-setup.git into my local agent skills directory.
If my agent uses the Codex-compatible skill layout, clone it to %USERPROFILE%\.codex\skills\wsl-vibecoding-setup on Windows, or ~/.codex/skills/wsl-vibecoding-setup on macOS/Linux.
If my agent uses another skills/plugins directory, use that configured directory instead.
After cloning, verify that SKILL.md exists and tell me how to invoke the skill.
```
