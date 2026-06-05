# SOP: State Workflow Operations (状态流转)

> **CRITICAL** — 开始前先读 [`../SKILL.md`](../SKILL.md)、[`workflow.md`](workflow.md)、[`error-handling.md`](error-handling.md)。

本 SOP 用于状态流工作项的状态变更操作。**仅适用于状态流**（pattern = State，如缺陷/issue），节点流请用 [`sop-transition-node.md`](sop-transition-node.md)。

> 此路径是 **conditional**（非 default-safe）。执行前先 `meegle inspect workflow.transition-state` 确认命令可用。

> 与上游 SaaS 版的关键差异（私有 cli）：
> - **按姓名查 userkey** 默认只用 `meegle user search --query "姓名" --project-key PROJ --format json`；若出现同名结果，展示候选 `email` / `user_key` 让用户确认。
> - **transition_id 必须从 query 获取**：不能猜测，每个空间/模板的 transition 配置不同。

---

## 写操作建模

流转前先明确：

- 目标对象：`project_key`、`work_item_type_key`、`work_item_id`、当前状态。
- 目标状态：目标状态名、`transition_id`、必填字段。
- 变更意图：推进、关闭、解决、重开或其他状态变更。
- 风险等级：状态流转是 conditional 写操作；通过 `inspect` 或 verified command surface 确认命令面，必要时保留必填项检查和用户确认。
- 结果核验：流转后回读状态，展示原状态、新状态、补充字段和执行结果。

## 执行流程

### STEP 1 — 定位工作项

从用户输入中提取 `work_item_id` 和 `project_key`：
- 用户给了 **URL** → `meegle url decode --url '<URL>' --format json`，再用 `space list` 转 `project_key`
- 用户给了 **ID** → 需同时确定 `project_key`（优先用 profile 默认值）
- 信息不足时才追问

同时确认 `work_item_type_key`：
- `url decode` 返回的 `work_item_type` 只是 `api_name`，**不是** `work_item_type_key`
- 必须调用 `meegle workitem meta-types --project-key PROJ --format json`，按 `api_name` 映射出真实 UUID 形态的 `work_item_type_key`
- 映射失败时不要继续 `workflow` 命令，先停下来列出候选类型或让用户确认

拿到 `project_key + work_item_type_key + work_item_id` 后，先做一次轻量预校验：

```bash
meegle workitem get \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-ids '[12345]' \
  --format json
```

只有 `workitem get` 能成功命中目标工作项时，才继续后面的 `workflow list-state-transitions` / `workflow transition-state`。如果这里就报 `WorkItem Not Found`，优先回查 `project_key` 或 `work_item_type_key` 是否映射错，**不要**直接把同样的三元组继续喂给 workflow。

### STEP 2 — 查询当前状态和可用流转

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```

从返回中获取：
- **当前状态**：`state_flow_nodes` 中 status = "doing" 的节点
- **可用流转**：`connections` 数组，每个 connection 包含 `transition_id`、`source_state_key`、`target_state_key`、`target_state_name`

**确定目标状态：**
- 用户指定了目标状态名（如"已解决"、"关闭"）→ 从 connections 中匹配 `target_state_name`
- 用户说"下一个状态" → 取当前状态的第一个可用 transition
- 匹配不到 → 列出所有可用目标状态供用户选择

**Fail-fast**：如果当前状态没有任何可用 transition（终态），立即告知用户"当前状态无法继续流转"。

### STEP 3 — 查询流转必填信息

```bash
meegle workflow list-state-required \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id <target_state_key> \
  --format json
```

从返回中识别需要补充的必填字段。如果没有必填字段，直接进入 STEP 4。

**硬拦截字段**：与节点流转相同，见 [`error-handling.md`](error-handling.md) 的 Hard-Block Field Types 表。遇到时立即告知用户。

### STEP 4 — 执行状态流转

```bash
meegle workflow transition-state \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --transition-id <transition_id> \
  --fields '[{"field_key":"xxx","field_value":"yyy"}]' \
  --format json
```

`--fields` 传入 STEP 3 中识别的必填字段值。状态流字段值格式同 `workitem update`：标量直接字符串化，数组/对象先 JSON.stringify。

**结果分支：**

| 结果 | 处理 |
|------|------|
| 流转成功 | 进入 STEP 5 |
| 必填字段未填/格式错误 | 补充字段后重试（最多 2 次） |
| 权限不足 | 告知用户，不重试 |
| transition_id 无效 | 重新 `workflow list-state-transitions` 获取最新 connections |

### STEP 5 — 确认结果

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```

验证状态已变更，向用户展示：
- 原状态 → 新状态
- 已补充的字段摘要（如有）

---

## 字段补充规则

当 STEP 3 返回必填字段时：

**人员字段处理：**
- 用户明确指定了人员 → 让用户提供 email/userkey
- 用户未指定但为必填 → **询问用户**，不自动默认

**通用字段转换**：`field_value` 协议层是 **STRING**；标量直接字符串化，数组/对象先 JSON.stringify。

**用户未提供值时**：
- 人员类 → **必须询问**
- 枚举类 → 列出选项让用户选
- 文本/数字/布尔 → 可给合理默认值
- 待确认字段 > 3 个时，一次性列出让用户批量回复

---

## 错误自愈

通用规则见 [`error-handling.md`](error-handling.md)。本 SOP 补充：

| 报错特征 | 自愈动作 |
|---------|---------|
| `transition_id` 无效 | 重新 `workflow list-state-transitions` 获取最新 connections |
| 必填字段未填 | 查 `workflow list-state-required` 后补充 |
| `need STRING type, but got: LIST` | field_value 忘了 JSON.stringify |
| 权限不足 | 告知用户，不重试 |

---

## 熔断条件

1. **当前状态为终态** — 无可用 transition，告知用户
2. **硬拦截字段阻塞** — 必填字段全部为不可写类型
3. **重试超过 2 次** — 同一流转失败 3 次，停止并报告完整错误
4. **transition_id 反复失效** — 可能是并发修改，告知用户刷新后重试
