# SOP: Node Workflow Operations (节点流转)

> **CRITICAL** — 开始前先读 [`../SKILL.md`](../SKILL.md)、[`workflow.md`](workflow.md)、[`error-handling.md`](error-handling.md)。

本 SOP 用于节点流工作项的节点完成（confirm）/ 回滚（rollback）操作。**仅适用于节点流**（pattern = Node），状态流请用 [`sop-transition-state.md`](sop-transition-state.md)。

> 此路径是 **conditional**（非 default-safe）。执行前先 `meegle inspect workflow.transition` 确认命令可用。

> 与上游 SaaS 版的关键差异（私有 cli）：
> - **按姓名查 userkey** 不可用：需要 userkey 时让用户提供 email 或 user_key。
> - **`workitem update` 的 `role_operate` 不可用**：但 `workflow transition` 的 `--role-assignee` 参数可以在流转时填充角色。

---

## 核心设计原则：最小查询 + 按需补充

`workflow transition` 只接受 `node_id`（节点 key），不支持节点名称。必须先通过 `workflow list-state-transitions` 获取名称→node_id 映射。但查询应尽可能精准轻量：

- 拿到 node_id 后**立即尝试流转**
- **仅当流转失败**（提示必填字段未填）时，才查询必填字段并补充

---

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
  --work-item-ids 12345 \
  --format json
```

只有 `workitem get` 能成功命中目标工作项时，才继续后面的 `workflow list-state-transitions` / `workflow transition`。如果这里就报 `WorkItem Not Found`，优先回查 `project_key` 或 `work_item_type_key` 是否映射错，**不要**直接把同样的三元组继续喂给 workflow。

### STEP 2 — 查询节点状态

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```

从返回中获取每个节点的 **name**、**node_id**（node_key）、**status**（finished/doing/not_started）。

**确定目标节点：**
- 用户指定了节点名 → 从返回中按 name 匹配取 node_id
- 用户说"当前节点" → 选 status = "doing" 的节点
- 用户说"所有节点" → 按顺序逐个处理未完成节点
- 用户没指定 → 自动选当前进行中的第一个节点
- 名称匹配不到 → 列出所有节点供用户选择

**确定操作类型：**
- "完成"、"流转"、"确认"、"推进" → action = `confirm`
- "回滚"、"退回"、"撤回" → action = `rollback`
- 未明确 → 默认 `confirm`

### STEP 2.5 — 预检必填项（主动扫描 + 用户确认，流转前必做）

从 `workflow list-state-transitions` 返回的目标节点数据中，**一次性**扫描所有可能缺失的值：

1. **fields[]**：找出 `field_value` 为 `null` / `""` / `[]` 的字段
2. **role_assignee[]**：找出 `owners` 为 `null` 或 `[]` 的角色
3. **schedules[]**：找出 `estimate_start_date == 0` 的排期

**扫描完成后，必须将所有空值项汇总成确认表格呈现给用户，等待用户明确确认后才能进入 STEP 3 流转。禁止跳过确认步骤自行填充后直接流转。**

确认表格格式示例：

> 节点【需求排期】有以下待填项，请确认后我将执行流转：
>
> | # | 字段 | 类型 | 建议值 / 可选项 |
> |---|---|---|---|
> | 1 | 整体排期 | 日期范围 | 请提供开始~结束日期 |
> | 2 | 规划迭代 | 关联工作项 | 请选择迭代（或提供 ID） |
> | 3 | 发布负责人 | 人员 | 请指定负责人 |
>
> 确认无误后回复"确认"或直接提供上述信息，我将一次性完成流转。

**各类型处理规则：**
- 人员类角色（owners 为空）：**必须询问用户，不可自行填充**
- 排期/日期类：**必须询问用户**
- 枚举/radio 类：列出所有可选项供用户选择，**不可自行选择**
- 关联工作项类：列出候选列表供用户选择
- 文本/数字类：可提供建议默认值，但需用户确认
- 布尔类：可默认 false，但需在表格中注明

**无空值时**：直接进入 STEP 3，无需打断用户。

### STEP 3 — 直接尝试流转

```bash
meegle workflow transition \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id <node_key> \
  --action confirm \
  --format json
```

如果已知必填字段（如 schedule 类型节点表单字段；这不是节点排期 `--schedules`），可以在 confirm 时一并传入：

```bash
# ⚠️ --fields 中 field_value 必须是原生 JSON object，不要 stringify
meegle workflow transition \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id <node_key> \
  --action confirm \
  --fields '[{"field_key":"field_225087","field_value":{"start_time":1779062400000,"end_time":1779321599000}}]' \
  --role-assignee '[{"role":"role_xxx","owners":["userkey1"]}]' \
  --format json
```

回滚时加 `--rollback-reason "原因"`。

**三种结果分支：**

| 结果 | 处理 |
|------|------|
| 流转成功 | 直接跳到 STEP 6 返回结果 |
| 必填字段未填写 | 进入 STEP 4 补充字段 |
| 其他错误（权限/节点不存在等） | 进入错误恢复逻辑 |

### STEP 4 — 按需补充必填字段（仅流转失败时）

**4.1 查询未完成的必填字段**

```bash
meegle workflow list-state-required \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id <node_key> \
  --format json
```

从返回中识别每个字段的 `form_item_type`（node_field / field）和 `field_type_key`。

**4.2 硬拦截：不可写入的字段类型**

以下字段类型 **API 无法写入**。如果被设为流转必填项，**立即中断当前节点的流转**并告知用户：

| 字段类型 | 拦截原因 |
|---------|---------|
| `actual_work_time` | 需在页面手动登记 |
| `node_finished_conclusion` | `update_node` 静默忽略，返回 success 但实际未写入 |
| `node_finished_opinion` | 同上 — 静默忽略 |
| `owners_finished_info` | 仅各负责人可在页面操作 |
| `vote-boolean` / `vote-option` / `vote-option-multi` | 仅支持页面交互 |
| `compound_field` / `multi_user_compound_field` | API 暂不支持 |
| `file` / `multi-file` | 需用户在页面上传 |
| 计算字段 | 只读 |

🚨 遇到硬拦截时输出：
> "节点流转受阻。当前节点【节点名称】要求必填【字段名称】（类型：xxx），该字段不支持 API 写入，请在页面手动填写后通知我继续。"

**4.3 可补充字段的值转换**

**节点专属属性**（不是 `--fields` 里的字段；使用 `workflow update-node` / `workflow transition` 的专用参数）：

| 节点属性 | 更新方式 |
|-----------|---------|
| `owner` (节点负责人) | `--node-owners '["userkey1","userkey2"]'` |
| `schedule` (节点排期，不是 schedule 字段) | `--schedules '{"estimate_start_date":ms,"estimate_end_date":ms,"points":N,"is_auto":false}'` |
| `point` (估分) | 通过 `schedules` 的 `points` 字段 |

**通用字段**（使用 `--fields` 参数）：

注意：`workflow transition` / `workflow update-node` 的 `--fields` 参数接受**原生 JSON object**，不需要 stringify。这与 `workitem update` 的 `--update-fields`（需要 stringify）不同。字段类型和合法 `field_key` 以 `workflow list-state-transitions` 返回的节点字段配置为准。

**schedule 类型字段在 --fields 中的正确格式（官方入参规范）：**

```json
[{"field_key": "field_225087", "field_value": {"start_time": 1722182400000, "end_time": 1722355199999}}]
```

- `start_time`: 毫秒时间戳，天精度，开始时间为 00:00:00
- `end_time`: 毫秒时间戳，天精度，结束时间为 23:59:59
- ❌ 错误：`"field_value": "{\"start_time\":...}"` — 不要 stringify
- ❌ 错误：`"field_value": "[1722182400000,1722355199999]"` — 不是数组格式
- ❌ 错误：`"field_value": {"estimate_start_date":...}` — 这是节点排期 `--schedules` 的格式，不是 `--fields` 中 schedule 类型字段的格式

**节点表单字段 vs 工作项字段**：
- `form_item_type = "node_field"` → 用 `workflow update-node` 或 `workflow transition --fields`
- `form_item_type = "field"` → 用 `workitem update`（工作项级别）
- ⚠️ **绝不能用 `workitem update` 更新节点表单字段**（如节点表单里的 schedule 类型字段 `field_225087`）。`workitem update` 会返回成功但值不会持久化（Pitfall #5：静默失败）。

**4.4 字段补充执行**

```bash
meegle workflow update-node \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id <node_key> \
  --node-owners '["userkey1"]' \
  --schedules '{"estimate_start_date":1722182400000,"estimate_end_date":1722355199999,"points":5,"is_auto":false}' \
  --fields '[{"field_key":"xxx","field_value":"yyy"}]' \
  --format json
```

⚠️ **节点负责人和排期不可同时更新**，需分两次调用 `workflow update-node`。

**4.5 用户未提供值时**：
- 人员类 → **必须询问用户**
- 排期/日期类 → **询问用户**
- 枚举类 → 列出选项让用户选
- 文本/数字/布尔 → 可给合理默认值（bool 默认 false，估分默认 1）
- 待确认字段 > 3 个时，一次性列出让用户批量回复

### STEP 5 — 补充后再次流转

字段补充完成后，**再次调用 `workflow transition`** 执行流转。仍然失败则读取错误信息重新处理（最多重试 2 次）。

### STEP 6 — 返回结果

展示表格汇总：

| 节点名称 | 操作 | 结果 | 备注 |
|---------|------|------|------|
| 需求评审 | confirm | ✅ 成功 | — |
| 开发中 | confirm | ✅ 成功 | 自动补充了排期、估分 |
| 测试中 | confirm | ❌ 阻塞 | 必填字段「实际工时」不支持 API 更新 |

如果有阻塞节点，明确列出需要用户手动操作的字段和原因。

---

## 批量流转

当用户说"所有节点"/"全部流转"时：
1. 按节点顺序依次流转：直接调 `workflow transition` → 失败则按需补充 → 下一个
2. 每个节点独立处理，某个节点被阻塞不影响已完成的节点
3. 最终汇总所有节点的结果表格

---

## 错误自愈

通用规则见 [`error-handling.md`](error-handling.md)。本 SOP 补充：

| 报错特征 | 自愈动作 |
|---------|---------|
| `node not found` | 重新 `workflow list-state-transitions` 获取真实 node_id |
| 必填字段未填 | 进入 STEP 4 按需补充 |
| `need STRING type, but got: LIST` | 仅在 `workitem update` 场景出现；`workflow transition --fields` 应传原生 JSON，不需要 stringify |
| `field [xxx] is illegal` | 该字段不能通过 `--fields` 更新，可能需要通过 `--schedules` 或 `--node-owners` 专用参数 |
| 权限不足 | 告知用户，不重试 |

---

## 熔断条件

1. **节点不存在** — `workflow list-state-transitions` 后仍无法定位目标节点
2. **硬拦截字段阻塞** — 必填字段全部为不可写类型，无法绕过
3. **重试超过 2 次** — 同一节点流转失败 3 次，停止并报告完整错误
