# SOP: Release Deploy Task

> **CRITICAL** — 开始前先读 [`../SKILL.md`](../SKILL.md)（前置检查、授权流程、命令参数参考、字段值格式、通用规范和错误处理），以及本目录下的 [`error-handling.md`](error-handling.md)、[`verified-command-surface.md`](verified-command-surface.md)、[`api-examples.md`](api-examples.md)。

本 SOP 用于在飞书项目的发布计划下准备、创建、执行、验证部署任务（deploy task），全程自动化执行。**仅适用于私有部署 CLI 工作流**。

---

## 适用场景

当用户要求对发布工作项（release work item）下的部署任务进行以下操作时使用本 SOP：

- 准备部署任务（prepare）
- 查看部署任务列表（list）
- 查看部署任务详情（inspect）
- 创建部署任务（create）
- 执行部署任务（execute）
- 验证部署任务（verify）

---

## 执行流程

### STEP 1 — 前置检查

运行 `meegle doctor --format json` 确认 CLI 环境正常、命令面可用。

### STEP 2 — 获取发布计划确认

如果用户尚未提供发布计划链接或发布计划工作项 ID，**停下来询问用户**。不要搜索历史记录、检查旧上下文、或代替用户探测候选发布计划。

### STEP 3 — 确认发布上下文

用户明确提供发布计划后，确认发布上下文：

```bash
meegle release deploy-task-list \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --format json
```

### STEP 4 — 失败任务前置检查（prior-failure gate）

如果 `deploy-task-list` 响应中包含一个或多个近期任务的 `deploy_status` 为 `"failed"`、`"rolled-back"`、`"rollback"` 或 `"terminated"`（即后端报告任务未成功完成或异常终止，terminated 表示手动取消/超时/系统中断），**先 `inspect` 这些任务**，向用户展示失败原因，并获得用户明确确认后再继续 `deploy-task-create`。

这是流程要求，不是 CLI 强制门控。

**`podStatus` / `readiness` 仅作辅助信号，信任 `deploy_status` 作为权威状态**。

### STEP 5 — 查看部署任务详情（可选）

如果用户指定了特定部署任务或想查看 pod 状态，inspect 它：

```bash
meegle release deploy-task-inspect \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordID RECORD_ID \
  --format json
```

### STEP 6 — 准备创建载荷（如需创建）

如果需要创建载荷，先从发布上下文准备：

```bash
meegle release deploy-task-prepare \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --appName APP_NAME \
  --format json
```

`prepare` 返回的 `latestVersions` 是 chart catalog 可用版本列表。**从列表中选择构建号最大的版本作为"catalog 最新"**（后端返回顺序可能不可靠）。catalog 可能被裁剪或旧版本被清理，导致某些历史部署过的版本不在列表中。如用户要求部署不在 `latestVersions` 中的版本，用 `--version` 探测该版本是否仍在 catalog 中。

### STEP 7 — 创建部署任务

**仅在 trigger 载荷明确后**创建部署任务。

创建前确认：

- 用户已为**本次部署请求**明确提供发布计划链接或发布计划工作项 ID
- 确认 `RELEASE_ID` 是为本次部署请求明确确认的发布计划
- 不要自动复用旧对话上下文、之前的部署尝试、或仅仅是进行中的发布计划列表中的发布计划
- 如果用户未确认本次部署应遵循哪个发布计划，停下来让用户确认现有发布计划或创建新发布计划
- 如果发布计划已完成，停止；不要在该发布计划下创建新部署任务

```bash
meegle release deploy-task-create \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --trigger '{"iBuildAppId":"APP_ID","feishuProjectID":"PROJ_ID","feishuOrderID":"RELEASE_ID","chartFullName":"REPO/CHART-1.2.3.tgz","builder":"USER_KEY","upgradeSummary":"Prepared from release RELEASE_ID","qualityAssurance":"USER_KEY"}' \
  --format json
```

### STEP 8 — 执行部署任务

**仅在目标任务集明确后**执行部署：

```bash
meegle release deploy-task-execute \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordIDs RECORD_ID_1 \
  --recordIDs RECORD_ID_2 \
  --format json
```

### STEP 9 — 监控部署任务状态

执行后，使用 `deploy-task-inspect --watch` 跟踪部署任务直到达到终态，而不是手动轮询：

```bash
meegle release deploy-task-inspect \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordID RECORD_ID \
  --watch \
  --interval 10s \
  --timeout 30m
```

`--watch` 将 inspect 从单次 JSON 响应切换为 NDJSON 流（每次轮询一行）。每轮都会注入相同的 `readiness` 软信号。

退出码：
- `0` = `deploy_status` 达到 `validated` 或 `completed`
- `1` = 任务达到 `rolled-back` / `rollback` / `terminated` / `failed`，或连续三次 inspect 失败
- `124` = `--timeout` 超时
- `130` = SIGINT

agent **应该**根据这些退出码分支，然后再继续 `deploy-task-verify`。

### STEP 10 — 应用白名单（如需要）

如果 execute 返回白名单指导（因为部署在允许窗口之外），停下来获取用户明确确认，然后应用白名单：

```bash
meegle release deploy-task-apply-white-list \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordIDs RECORD_ID_1 \
  --format json
```

### STEP 11 — 验证部署任务

**仅在执行状态已知后**验证：

```bash
meegle release deploy-task-verify \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --validation '{"recordID":"RECORD_ID_1","validation":10}' \
  --format json
```

---

## 公开命令面约束

v1 公开 CLI 不暴露底层 Kubelink 命令族。

如果任务需要隐藏的 Kubelink MCP 工具，停下来并解释当前公开 CLI 仅支持此领域的 release 层 `release deploy-task-*` 工作流。

---

## 规则

- 将 `release deploy-task-prepare/list/inspect` 视为默认安全的首选操作
- 将 create/execute/verify/upgrade/apply-white-list 风格的命令视为条件操作
- 在发布上下文、目标记录和预期副作用明确之前，不要执行条件部署任务命令
- 如果 `inspect` 输出显示 `recordID` 与提供的发布上下文不匹配，停下来解决该不匹配，然后再写入

---

## 恢复注意事项

- 如果 `doctor` 无法发现 deploy-task 命令，将其视为 CLI 与远程 MCP 服务器之间的命令面漂移，而不是缺少 Kubelink CLI 配置
- 如果 `prepare` 返回 `can_continue=false`，检查原因并在创建任何内容之前解决 app/chart 歧义
- 如果 `execute` 或 `verify` 需要 release 层无法表达的精确底层 Kubelink 载荷，停下来并告诉用户公开 CLI 尚未暴露该操作
- 如果错误信息提到用户未直接调用的工具（如 `Invalid arguments for tool meegle_workflow_query`），这是后端 MCP 服务器内部工具链错误，不是用户参数问题。告知用户这是后端服务问题，需联系运维修复

---

## 验收用例：当前请求的明确发布计划确认

使用此验收用例从面向用户的工作流验证生产 deploy-task 规则。

**前提条件**：

- `RELEASE_ID_ACTIVE` 是为当前部署请求明确选择的发布计划，其工作流仍在进行中
- `RELEASE_ID_DONE` 是已完成的发布计划，不再适合创建新 deploy-task
- 操作员已有有效的 `trigger` 载荷，或可通过 `release deploy-task-prepare` 生成

**验收步骤**：

1. 从新的部署请求开始，例如"将应用 X 部署到生产环境"
2. 不要立即创建。首先确认此请求遵循哪个发布计划
3. 如果用户尚未确认发布计划，停留在只读路径命令，例如：

```bash
meegle release deploy-task-list \
  --project-key PROJ \
  --release-id RELEASE_ID_ACTIVE \
  --format json
```

或：

```bash
meegle release deploy-task-prepare \
  --project-key PROJ \
  --release-id RELEASE_ID_ACTIVE \
  --appName APP_NAME \
  --format json
```

4. 用户明确确认 `RELEASE_ID_ACTIVE` 用于此部署请求后，创建部署任务：

```bash
meegle release deploy-task-create \
  --project-key PROJ \
  --release-id RELEASE_ID_ACTIVE \
  --trigger '{"iBuildAppId":"APP_ID","feishuProjectID":"PROJ_ID","feishuOrderID":"RELEASE_ID_ACTIVE","chartFullName":"REPO/CHART-1.2.3.tgz","builder":"USER_KEY","upgradeSummary":"Prepared from release RELEASE_ID_ACTIVE","qualityAssurance":"USER_KEY"}' \
  --format json
```

**预期结果**：

- 发布计划预检通过
- 命令被允许到达后端执行
- 工作流将此视为有效的创建尝试，因为发布计划已为当前请求明确确认且仍未完成

5. 用 `RELEASE_ID_DONE` 重复相同的 create 命令：

```bash
meegle release deploy-task-create \
  --project-key PROJ \
  --release-id RELEASE_ID_DONE \
  --trigger '{"iBuildAppId":"APP_ID","feishuProjectID":"PROJ_ID","feishuOrderID":"RELEASE_ID_DONE","chartFullName":"REPO/CHART-1.2.3.tgz","builder":"USER_KEY","upgradeSummary":"Prepared from release RELEASE_ID_DONE","qualityAssurance":"USER_KEY"}' \
  --format json
```

**预期结果**：

- CLI 在后端写入执行前拒绝命令
- 错误代码是 `RELEASE_PLAN_COMPLETED`
- 下一步操作是确认另一个进行中的发布计划或先创建新发布计划

如果工作流静默复用旧的 `RELEASE_ID`、自动选择任何进行中的发布计划、或允许在已完成的发布计划下 `deploy-task-create`，则此用例不满足。
