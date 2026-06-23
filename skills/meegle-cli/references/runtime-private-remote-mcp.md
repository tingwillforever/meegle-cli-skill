# Private Runtime: Installed CLI + Remote MCP

This repository's private deployment runtime is now:

- installed `meegle` CLI
- remote MCP Server
- SSO-backed session created by `meegle auth login`

It is not a local `stdio` / bundled `meegle-mcp` workflow.

## Required runtime model

- `meegle` installed from the published package
- built-in remote MCP endpoint, or an active profile override with `mcp_server_url`
- successful `meegle auth login`

## On-demand diagnostics

不要把 `meegle doctor --format json` 当成每次业务命令的固定前置。默认直接走业务命令；只有在以下情况再跑 `doctor`：

- 用户主动要求诊断
- 登录 / 认证 / 配置异常
- 业务命令报错但错误信息不足以定位根因
- `inspect --format json` 显示 `runtime_source != "live"`，或怀疑命令面漂移

```bash
meegle doctor --format json
```

重点看：

- `overall_status`
- `checks[].name == "runtime_source"`
- `checks[].name == "descriptor_drift"`
- `checks[].name == "live_descriptor"`

理想状态：

- `overall_status: ok`
- `runtime_source.status: ok`
- `runtime_source.details.runtime_source: "live"`
- `descriptor_drift.status: ok`

如果 `doctor` 显示：

- `runtime_source == "snapshot"`：当前 public runtime 仅适合只读诊断；不要继续执行业务命令
- `descriptor_drift != ok`：视为 CLI 与远端 public descriptor 漂移，先修复环境/发布链路
- `live_descriptor != ok`：先修复 runtime/auth/config，再继续业务命令

## Installation model

Typical private installation:

```bash
npm install -g @tingwillforever/meegle-cli
```

## Bootstrap

Default local acceptance:

```bash
meegle auth login
meegle auth status
```

Expected login outcomes:

- `Login successful`: remote MCP session is ready for business commands
- `No project membership found`: SSO passed, but the account is not a role-owner on any project-management work item in the configured space

In the `no project membership` case, ask an administrator to add the account to the relevant project-management work item's role members, then retry `meegle auth login`.

Temporary endpoint override:

```bash
meegle auth login --mcp-server-url https://mcp.example.com/mcp
```
