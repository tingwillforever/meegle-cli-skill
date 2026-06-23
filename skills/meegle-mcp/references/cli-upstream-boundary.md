# CLI Upstream Boundary

本文件标记 CLI-heavy upstream reference 在 public MCP skill 中的处置方式。它用于边界判断，不是默认执行路径。

## Disposition

| CLI upstream reference | MCP 处置 |
|---|---|
| `api-examples.md` | example-only；只能改写成 MCP-native examples 或 eval seed，不作为运行时事实源 |
| `cli-guide.md` | adapted/gap；只迁移“不要猜参数、以 schema 为准、写后验证”等原则，不迁移 CLI flag |
| `verified-command-surface.md` | adapted；MCP 以 public command manifest 和 drift check 为事实源 |
| `mql-syntax.md` | gap/out-of-scope；当前 public MCP 没有 MQL tool，不生成 MQL 查询 |
| `url-kinds.md` | adapted/gap；URL 解析交给平台结构化锚点，skill 不从 URL 路径猜参数 |
| `runtime-private-remote-mcp.md` | adapted；CLI install/doctor/login 叙事下沉到部署文档，direct MCP 使用 bearer session/OAuth 接入 |
| `auth-guard.md` | adapted；认证成功但无项目权限时停止，不能继续业务命令 |

## Rules

- 不把示例命令当作 live contract。
- 不把 CLI-only helper 写成 direct MCP 默认步骤。
- 不把 CLI command coverage 数字当成 MCP tool coverage。
- 不把 MQL、workhour、mywork 等未暴露能力伪造成 public MCP tool。

## 可复用原则

可以迁移：

- 事实源层级。
- 不猜字段、不猜类型、不猜状态。
- destructive / conditional 门禁。
- 写后 readback。
- capability gap 诚实暴露。

不能迁移：

- shell flag。
- local profile。
- 本地文件路径读取语义。
- CLI doctor/inspect 的运行时诊断路径。
