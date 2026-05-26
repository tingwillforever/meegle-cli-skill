# Meegle Skill

这个仓库提供公开的 `meegle` skill，供 AI Agent 工具使用。

`meegle` skill 会帮助你的 Agent 学会如何通过 Meegle CLI 使用 Meegle。
其中，CLI 负责执行命令，skill 负责给 Agent 正确的调用指引。

## 安装前准备

请先安装最新版 Meegle CLI：

```bash
npm install -g @tingwillforever/meegle-cli
```

CLI 包地址：

- [@tingwillforever/meegle-cli on npm](https://www.npmjs.com/package/@tingwillforever/meegle-cli)

完整的 CLI 安装、登录和使用说明请参考 npm 包页面。

## 安装 skill

安装好 CLI 后，再添加 `meegle` skill：

```bash
npx -y skills add https://github.com/tingwillforever/meegle-cli-skill --skill meegle -g -y
```

## 这个 skill 能帮你做什么

`meegle` skill 会帮助你的 Agent：

- 理解常见的 Meegle 工作流
- 选择合适的 Meegle CLI 命令
- 用更稳妥的方式执行日常操作
- 减少在 Agent CLI 场景下的命令和参数错误

## 适合谁使用

这个仓库适合希望在以下 AI Agent 工具中使用 Meegle 的用户：

- Codex
- Claude Code
- Cursor
- Gemini CLI
- GitHub Copilot CLI

## 安装完成后

安装好 CLI 和 skill 后，你就可以直接用自然语言让 Agent 帮你处理 Meegle 相关任务。

首次实际使用前，建议先按 CLI 文档完成登录，例如：

```bash
meegle auth login
```

然后就可以直接提问，例如：

```text
帮我看一下 PROJ 空间本周的 P0 工作项
```
