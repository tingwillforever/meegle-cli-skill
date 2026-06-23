# Meegle Skills

这个仓库是公开可安装的 Meegle skill mirror，统一发布两套 skill：

- `meegle-cli`：给本机安装了 `meegle` CLI 的用户使用
- `meegle-mcp`：给业务方 Agent 平台或 MCP-native 宿主使用

它只负责对外分发，不是新的事实源。

## 安装 `meegle-cli`

先安装 CLI：

```bash
npm install -g @tingwillforever/meegle-cli
```

然后安装 CLI skill：

```bash
npx -y skills add https://github.com/tingwillforever/meegle-skills --skill meegle-cli -g -y
```

适用场景：

- 用户在本机通过 `meegle` CLI 访问私有化部署
- Agent 需要学习如何选择正确的 CLI 命令、SOP 和安全停点

首次实际使用前，先完成登录：

```bash
meegle auth login
```

## 安装 `meegle-mcp`

如果你的宿主是业务方 Agent 平台，或能直接连接远端 `meegle-mcp` Server 的 MCP-native 客户端，安装 MCP skill：

```bash
npx -y skills add https://github.com/tingwillforever/meegle-skills --skill meegle-mcp -g -y
```

适用场景：

- 普通用户 -> 业务方 Agent 平台 -> 远端 `meegle-mcp`
- 宿主直接给 Agent 暴露 `preset.public` 与 canonical MCP skill

## Source Of Truth

公开 mirror 的 canonical source 仍分属两个 owning repository：

- `tingwillforever/meegle-cli` 中的 `skills/meegle-cli/`
- `tingwillforever/meegle-mcp` 中的 `skills/meegle-mcp/`

这个仓库只发布经过 review 的公开安装内容，不单独定义 CLI 或 MCP 语义。
