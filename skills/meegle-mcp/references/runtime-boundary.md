# Runtime Boundary

本文件定义 direct public MCP 与 CLI public surface 的边界，避免把 CLI 假设误带到业务方直连 MCP 的场景里。

## 事实源

direct MCP 的默认事实源只有：

- `preset.public`
- public command manifest 对应的 52 个 MCP tools
- 这些 tools 的 live schema 与真实返回

不要依赖：

- `meegle` CLI 包装能力
- 非 public MCP tools
- 用户本地 profile 配置
- 历史 transcript / 样例输出

## 与 CLI 的关键差异

### CLI-only helper 对照表

| CLI helper / 语义 | direct MCP 处理 |
|---|---|
| `url decode` | direct MCP 默认没有 URL parser；需要平台提供结构化页面锚点，或停止并说明缺口 |
| `inspect` | 不作为运行时工具；参数和可用性以 public manifest 与 live MCP schema 为准 |
| `doctor` | 不作为业务前置；诊断交给平台日志、MCP 错误和运维文档 |
| `auth whoami` | 当前用户默认用 `meegle.user.query` + `current_login_user()` |
| local profile / default context | 不读取用户本机配置；只消费 bearer session、MCP session 或平台注入上下文 |
| `--select` / `--output-select` | 不迁移 CLI projection flag；回答阶段基于结构化返回本地整理 |
| `--dry-run` | 不作为 direct MCP 默认路径；写操作用 preflight、确认门禁和 readback 控制风险 |

### 1. 没有 `url decode`

direct MCP 无法把业务 URL 直接解析成 `project_key`、`view_id`、`work_item_id`、`chart_id`。

因此：

- 没有平台侧 URL parser 时，不把“给一个 Meegle URL 就能读”当作 direct MCP 默认承诺
- 如果用户已直接给出结构化锚点，例如 `project_key + work_item_id`，则可继续执行

### 2. 没有 `inspect` / `doctor`

direct MCP 无 CLI 参数面诊断层。

因此：

- 以 live MCP schema 为准
- 不提供 CLI 那种 `runtime_source` / `snapshot_stale` 诊断语义
- tool 可不可用，以是否在 public manifest 中为准

### 3. 当前用户语义不同

CLI 里通常走 `auth whoami`；direct MCP 默认改成：

- `meegle.user.query` + `current_login_user()`

如果平台自己额外提供 session context，可以作为增强，但不是 skill 默认依赖。

不过，空间默认值不是同一件事。ordinary-user session 的 `projectKeys` 已经是服务端授权事实的一部分；当 session 只暴露一个 `projectKeys` 时，skill 应直接把它当默认 `project_key`，而不是继续把该空间降级成“待确认候选值”。

### 4. 事件形态不同

真实 direct MCP run 在 `codex exec --json` 中表现为：

- `agent_message`
- `mcp_tool_call`

不是 CLI eval 中的 `command_execution`。

这意味着 direct MCP 评测需要专门的 normalizer。

## Shared surface 与 capability gap

### Shared surface

下列场景适合与 CLI 做可比对评测：

- 空间、类型、业务线发现
- 工作项按 ID 读取
- 工作项 search.filter / search.byParams
- 字段元数据读取
- 视图 list / fixed-items 读取
- 工作流 query / requiredInfo

### Capability gap

下列场景目前不要承诺与 CLI 等价：

- 基于 URL 的 decode-first 路径
- 依赖 CLI `inspect` 决定 projection / dry-run 的路径
- 依赖 `doctor` 的诊断型 case
- 依赖本地 profile 默认值暴露的上下文推断；但服务端 session 已唯一给出的默认空间不属于这类 gap

## 平台侧可选增强

如果业务方平台愿意补一层 platform helper，会显著提升效果：

- URL parser，把业务 URL 先解析成结构化参数
- 当前空间 / 当前对象上下文注入
- 用户默认偏好（如默认 project_key）

这些增强可以让 direct MCP 更接近 CLI 体验，但不应写成 skill 的硬前置。

如果服务端 session 已经只暴露一个 `projectKeys`，平台无需额外再补一个“默认空间确认”helper；skill 应直接消费这份现成事实。

平台宿主能力的输入 contract 见 [platform-context.md](platform-context.md)。CLI-heavy upstream 内容的处置见 [cli-upstream-boundary.md](cli-upstream-boundary.md)。
