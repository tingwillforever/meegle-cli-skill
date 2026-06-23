# SOP: Release Deploy Task

本 SOP 用于 public MCP 下发布计划部署任务的准备、创建、执行和验证。创建不等于执行，执行不等于业务验证通过。

## Intent Routing

先判断用户本轮要到哪一步，并在对应停止点停下：

| 用户意图 | MCP tool path | 停止点 |
|---|---|---|
| 查看部署任务 / 查看结果 | `meegle.release.deployTask.inspect`；按需 `meegle.release.deployTask.list` | 输出当前状态后停止 |
| 创建部署任务 | `prepare` -> `create` -> `inspect` 新 `recordID` | 输出新任务状态后停止 |
| 创建并执行部署 | `prepare` -> `create` -> `inspect` -> `execute` -> `inspect` | 输出提交后最新状态后停止 |
| 执行已有部署任务 | `inspect` gate -> `execute` -> `inspect` | 输出提交后最新状态后停止 |
| 等待部署完成 | execute 后重复 `inspect` | 到用户要求的终态后停止 |
| 提交验证通过/不通过 | `verify` | 输出验证提交结果后停止 |

不要把“创建部署任务”理解为“创建并执行部署”，也不要把“执行部署”理解为“业务验证通过”。

## Hard Gates

- 发布计划必须由用户在本次请求中明确提供：发布计划工作项 ID，或平台提供的结构化页面锚点。
- 没有结构化 release context 时停止；direct MCP 没有 URL decode。
- 不复用旧对话、历史部署尝试或自动选择进行中的发布计划。
- 如果发布计划已完成，停止；不要在已完成计划下创建新任务。
- create / execute / verify / applyWhiteList 都是 conditional 写操作；目标记录和副作用不明确时不要执行。
- 列表读取不是固定前置；只有用户要求审计历史，或 create/execute 发生冲突、失败、上下文不匹配时才 list。

## Prepare

创建前调用：

- `meegle.release.deployTask.prepare`

规则：

- 如果返回中存在多个 app/chart/version 候选，先让用户确认。
- 如果用户指定版本不存在或 `can_continue` 语义不允许继续，停止。
- 不按返回顺序猜最新版本，除非返回明确提供可比较版本信息。

## Create

仅在 trigger 载荷明确后调用：

- `meegle.release.deployTask.create`

创建后：

1. 从 create 返回中读取本轮新 `recordID`。
2. 只 inspect 这个新 `recordID`。
3. 如果用户只要求创建，汇报 `appName`、版本、`recordID`、`deploy_status`、`allow_release` 和下一步可选动作后停止。
4. 不自动 applyWhiteList、execute 或 verify。

输出字段和停点按 [result-display.md](result-display.md) 的 write readback 合同执行；不要只说“创建成功”而不列 `recordID`、状态和下一步。

## Execute

仅在用户意图包含 execute 且 gate 通过后调用：

- `meegle.release.deployTask.execute`

execute gate 必须同时满足：

- `recordID` 来自本轮 create 返回，或由用户明确指定。
- `recordID` 与当前 `project_key` / `release_id` 上下文匹配。
- `deploy_status == "pending"`。
- `allow_release == true`。

如果用户给的是已有 `recordID`、上次 inspect 已过期、状态不是 `pending`、`allow_release == false` 或上下文不清楚，必须重新 inspect。

如果用户只要求创建且 `allow_release == false`，只汇报当前不可执行，不自动申请白名单。

只有用户意图包含 execute，且当前状态是 `pending` 但 `allow_release == false` 时，才调用：

- `meegle.release.deployTask.applyWhiteList`

白名单申请后重复 inspect，直到 `allow_release == true` 且 `deploy_status == "pending"` 再 execute；若状态进入审批中或失败终态，停止并汇报。

## Execute 后汇报

execute 成功只表示执行请求已提交。执行后必须 inspect 一次最新状态，并按这个口径汇报：

```text
部署执行请求已提交，recordID=...。最新查询状态为 ...。请关注发布/部署通知和业务侧验证结果。业务验证完成后，可以告诉我“验证通过”或“验证不通过”，我再帮你提交验证结论。
```

## Verify

仅当用户明确表示“验证通过”“验证不通过”或“提交验证结果”后调用：

- `meegle.release.deployTask.verify`

不要从 `deploy_status`、通知、pod 状态或经验推断业务验证结论。

验证枚举：

- 验证通过：`10`
- 验证失败 / 验证不通过：`11`

## Stop Conditions

- 缺少本次请求明确的 release context。
- 发布计划已完成。
- `recordID` 与 release context 不匹配。
- `deploy_status` 不是可执行状态。
- `allow_release == false` 且用户没有要求执行。
- 需要 raw integration 载荷或 hidden tool 才能完成。
- 用户没有明确验证结论。
