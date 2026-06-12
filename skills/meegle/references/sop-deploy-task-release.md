# SOP: Release Deploy Task

> **CRITICAL** — 开始前先读 [`../SKILL.md`](../SKILL.md)，以及本目录下的 [`error-handling.md`](error-handling.md)、[`verified-command-surface.md`](verified-command-surface.md)、[`api-examples.md`](api-examples.md)。

本 SOP 用于在飞书项目发布计划下准备、创建、执行和验证 deploy task。按用户明确意图分段执行；创建不等于执行，执行不等于业务验证通过。

---

## 意图路由

先判断用户本轮要到哪一步，并在对应停止点停下：

| 用户意图 | 执行路径 | 停止点 |
|---|---|---|
| 查看部署任务 / 查看结果 | inspect；按需 list | 输出当前状态后停止 |
| 创建部署任务 | prepare -> create -> inspect(new recordID) | 输出新任务状态后停止 |
| 创建并执行部署 | prepare -> create -> inspect(new recordID) -> execute -> inspect | 输出提交后最新状态后停止 |
| 执行已有部署任务 | inspect(gate) -> execute -> inspect | 输出提交后最新状态后停止 |
| 等待部署完成 | execute 后重复 inspect | 到用户要求的终态后停止 |
| 提交验证通过/不通过 | verify | 输出验证提交结果后停止 |

不要把“创建部署任务”理解为“创建并执行部署”，也不要把“执行部署”理解为“业务验证通过”。

## 硬门禁

- 运行态：默认直接进入 release 命令；只有登录/配置异常、只读命令报错难以定位，或 `inspect --format json` 显示 `runtime_source != "live"` 时，才运行 `meegle doctor --format json`。
- 发布计划：用户必须为**本次请求**明确提供发布计划链接或发布计划工作项 ID。不要复用旧对话、历史部署尝试或自动选择进行中的发布计划。
- 完成态：如果发布计划已完成，停止；不要在该发布计划下创建新 deploy task。
- 命令面：只使用公开 `release deploy-task-*` 命令。若任务需要隐藏 Kubelink MCP 工具，停止并说明公开 CLI 尚未暴露该操作。
- 状态源：`deploy_status` 是权威状态；`podStatus` / `readiness` 只作辅助信号。
- 写操作：create / execute / verify / apply-white-list 都是 conditional 写操作；上下文、目标记录和副作用不明确时不要执行。
- 列表读取：不要把完整 `deploy-task-list` 作为固定前置。后端 list 当前不支持 app/latest 服务端过滤；只有用户要求审计历史、或 create/execute 返回冲突、失败、上下文不匹配等诊断信号时才 list。

## 命令模板

### Inspect

查看指定任务或写后核验：

```bash
meegle release deploy-task-inspect \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordID RECORD_ID \
  --format json
```

### List

仅用于用户明确要求列表/审计历史，或排查失败/冲突：

```bash
meegle release deploy-task-list \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --format json
```

如果目标 app 的近期任务是 `"failed"`、`"rolled-back"`、`"rollback"` 或 `"terminated"`，先 inspect 失败任务并展示原因，再决定是否继续。

### Prepare

创建前先准备发布上下文：

```bash
meegle release deploy-task-prepare \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --appName APP_NAME \
  --format json
```

- `latestVersions` 是 chart catalog 可用版本列表；选择构建号最大的版本作为 catalog 最新，不能依赖返回顺序。
- 如果用户指定版本不在 `latestVersions` 中，用 `--version` 探测该版本是否仍在 catalog 中。
- 如果 `can_continue=false`，先解决 app/chart 歧义，不要 create。

### Create

仅在 trigger 载荷明确后创建：

```bash
meegle release deploy-task-create \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --trigger '[{"iBuildAppId":"APP_ID","feishuProjectID":"PROJ_ID","feishuOrderID":"RELEASE_ID","chartFullName":"REPO/CHART-1.2.3.tgz","builder":"USER_KEY","upgradeSummary":"Prepared from release RELEASE_ID","qualityAssurance":"USER_KEY"}]' \
  --format json
```

创建后立即执行：

1. 从 `workflow.execute.releases[].recordID` 取本轮新建 `recordID`。
2. 只 inspect 这个新 `recordID`，不要通过 list 反查最新任务。
3. 如果用户只要求创建，汇报 `appName`、版本、`recordID`、`deploy_status`、`allow_release` 和下一步可选动作后停止。
4. 创建任务后不要自动 apply-white-list、execute 或 verify。

### Execute

仅在用户意图包含 execute 且执行 gate 通过后执行：

```bash
meegle release deploy-task-execute \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordIDs '["RECORD_ID"]' \
  --format json
```

执行 gate：

- `recordID` 来自本轮 create 返回，或由用户明确指定
- `recordID` 与当前 `project_key` / `release_id` 上下文匹配
- `deploy_status == "pending"`
- `allow_release == true`

若 create 后刚 inspect 且 gate 已满足，不要为了 execute 重复 inspect。若用户给的是已有 `recordID`、上次 inspect 已过期、状态不是 `"pending"`、`allow_release == false` 或上下文不清楚，必须重新 inspect。

如果用户只要求创建且 `allow_release == false`，只汇报“当前不可执行 / 需要白名单”，不要自动申请白名单。只有用户意图包含 execute，且 `deploy_status == "pending"`、`allow_release == false` 时，才申请白名单：

```bash
meegle release deploy-task-apply-white-list \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordIDs '["RECORD_ID"]' \
  --format json
```

白名单申请成功后轮询 inspect，直到 `allow_release == true` 且 `deploy_status == "pending"` 再 execute。若状态为 `"approving"`，等待审批；若状态变成 `"terminated"` / `"failed"`，停止并汇报失败原因。

### Execute 后汇报

`deploy-task-execute` 成功只表示执行请求已提交，不表示部署成功，也不表示业务验证通过。执行后必须 inspect 一次最新状态，并按这个模板汇报：

```text
部署执行请求已提交，recordID=RECORD_ID。最新查询状态为 DEPLOY_STATUS。请关注发布/部署通知和业务侧验证结果。业务验证完成后，可以告诉我“验证通过”或“验证不通过”，我再帮你提交验证结论。
```

状态口径：

- `"pending"`：执行请求可能已提交，但后端编排尚未开始处理或状态尚未刷新
- `"deploying"`：部署正在执行
- `"validating"`：部署已进入待业务验证 / 验证阶段
- `"failed"` / `"terminated"` / `"rolled-back"`：停止后续动作，汇报失败原因，不提交 verify

当前 public CLI 不暴露 `deploy-task-inspect` 的 watch / interval / timeout 参数。只有用户明确要求等待终态时，才按用户确认的节奏重复执行只读 inspect，直到 `"completed"` / `"terminated"` / `"failed"` / `"rolled-back"` 等终态。

### Verify

仅在用户明确表示“验证通过”“验证不通过”或“提交验证结果”后验证。不要从 `deploy_status`、通知、pod 状态或经验推断业务验证结论。

验证结论枚举：

| 用户结论 | `validation` |
|---|---:|
| 验证通过 | `10` |
| 验证失败 / 验证不通过 | `11` |

提交验证通过：

```bash
meegle release deploy-task-verify \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --validation '[{"recordID":"RECORD_ID","validation":10}]' \
  --format json
```

提交验证失败 / 验证不通过：

```bash
meegle release deploy-task-verify \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --validation '[{"recordID":"RECORD_ID","validation":11}]' \
  --format json
```

## 恢复口径

- 如果 `doctor` 无法发现 deploy-task 命令，将其视为 CLI 与远程 MCP Server 的命令面漂移。
- 如果 `execute` 或 `verify` 需要 release 层无法表达的精确底层 Kubelink 载荷，停止并说明公开 CLI 尚未暴露该操作。
- 如果错误信息提到用户未直接调用的工具（如 `Invalid arguments for tool meegle_workflow_query`），这是后端 MCP Server 内部工具链错误，不是用户参数问题；告知用户需联系运维修复。
