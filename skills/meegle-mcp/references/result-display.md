# Result Display

本文件定义 public MCP 下的最终回答展示合同。目标是让业务方 Agent 平台在 shared public surface 场景里接近 CLI skill 的结果呈现，而不是只把 MCP raw tool output 摘成 ID/name。

## Default work item list page

工作项列表、搜索结果、固定视图展开后的工作项详情，默认展示一个有界小页：

- 默认展示当前工具返回页，最多前 10 条；如果工具只返回少于 10 条，就全部展示。
- 如果返回 `pagination.total` / `page_num` / `page_size`，说明“共命中 N 条，当前展示 M 条”。
- 不要因为 `pagination.total` 大于当前页就自动扩大分页；用户要求“继续 / 全部 / 导出”时再翻页。
- 当前页已经有足够字段时，不要先问用户“是否继续整理成表格”；直接整理并回答。
- 已成功的最终查询是当前业务语义的事实源。不要为了展示字段把 `user_keys`、关联字段、状态等过滤条件改写成另一个查询；这会改变用户意图。
- 工具输出很长或宿主 transcript 显示截断时，不要把它当作必须重新查询的业务失败；展示当前可确认字段即可。

默认列：

| 列 | 取值规则 |
|---|---|
| `ID` | 顶层 `id` |
| `名称` | 顶层 `name` |
| `当前状态/节点` | 优先使用已读 `work_item_status.options[]` 映射；否则用 `current_nodes[].name`；再否则标注 raw `state_key` |
| `当前负责人` | 从 `fields[]` 的 `field_key` / `field_alias == "current_status_operator"` 读取；缺失时可用 `owner` 作为弱 fallback 并说明口径 |
| `创建时间` | 顶层 `created_at`，它是毫秒时间戳 |

只要当前页工作项对象里有 `created_at`，最终表格就必须包含 `创建时间` 列。能确定性格式化就输出格式化时间；不能格式化就直接输出原始毫秒值或返回中的 ISO。不要把“带上创建时间”留成下一步可选项，也不要因为缺少格式化能力而省略该列。

用户明确要求更少列时，至少保留用户要求的字段；用户要求“详情 / 完整字段 / 导出”时再扩大字段或分页。

## Readable value rules

- 状态：如果本轮已经调用 `meegle.workitem.meta`，用其中 `work_item_status.options[]` 做 `value -> label` 映射；不要为了状态 label 重复读取同一份元数据。
- 节点：如果没有状态映射且 `current_nodes[]` 有 `name`，直接显示节点名。
- 人员：优先复用字段值中的 `label` / `name` / `display_name`；如果本轮已通过 `meegle.user.query` 解析过同一个 user key，复用该姓名。
- 人员 raw key：当前页只剩 raw `user_key` 且用户未要求 raw 时，最多一次 `meegle.user.query` 批量回填当前页唯一 key；失败或用户要求 raw 时，展示原始 `user_key` 并标注 raw。
- 枚举：`select` / `multi-select` / `tree-select` 等优先显示 `label`；只有排障或无映射时才显示 raw `value`。
- 时间：`created_at` / `updated_at` 是 Unix epoch 毫秒，不是秒。可以用平台或宿主的确定性时间格式化为 `Asia/Shanghai`；如果无法确定性转换，展示毫秒或返回中的 ISO，不要心算人类时间。

## Field location boundary

工作项对象按两层读取：

- 稳定顶层字段：`id`、`name`、`current_nodes`、`work_item_status`、`created_at`、`updated_at`、`created_by`、`updated_by`、`deleted_at`、`deleted_by`、`work_item_type_key`、`project_key`、`simple_name`、`pattern`、`sub_stage`、`template_id`、`template_type`、`fields`。
- 业务字段：`current_status_operator`、`owner`、`priority`、`business`、`watchers`、`role_owners`、`description`、`template`、`field_*`、关联字段、枚举字段等默认从 `fields[]` 读取。

不要把 `current_status_operator` 当成稳定顶层字段；也不要在 `fields[]` 里找标题。

## Output templates

### Work item list

```text
共命中 N 条，当前展示 M 条：

| ID | 名称 | 当前状态/节点 | 当前负责人 | 创建时间 |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

说明：当前负责人来自 ...；无法映射的值已标注 raw。
```

### Fixed/system view

```text
视图读取完成：view_id=...，view_type=...，work_item_id_list 共 N 个。

| ID | 名称 | 当前状态/节点 | 当前负责人 | 创建时间 |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |
```

如果只读取了 `work_item_id_list`，尚未调用 `meegle.workitem.get`，不要伪造标题、状态或负责人；但一旦已经 get 了工作项详情，就按工作项列表合同展示。

### Write readback

写操作最终回答必须包含：

- 目标身份：`project_key`、`work_item_type_key`、`work_item_id` / `view_id` / `node_id` / `recordID`
- 已提交动作：创建、更新字段、状态流转、节点操作、评论/附件/子任务操作、发布部署动作
- readback / inspect 证据：回读到的名称、状态、字段值、部署状态或验证停点
- 未完成项：未写入字段、权限拦截、hard-block 字段、仍需用户确认的下一步

不要只凭 success response 说“已完成”；复杂字段、流程和部署任务必须基于 readback / inspect 结果下结论。

## Cost budget

- 同一最终查询不要为展示格式重复调用。
- 同一工作项类型最多一次字段元数据读取。
- 同一展示页最多一次人员回填查询。
- 允许对当前页 ID 做一次 `meegle.workitem.get` 补负责人字段；这不是同条件列表重查，不能扩大到全量分页。
- 如果当前页回包太大或宿主显示被截断，仍不要换过滤条件重查。只能基于已拿到的 ID 做 `meegle.workitem.get` 补展示字段；如果 ID 也无法完整取得，就展示已确认的当前页并说明哪些字段未确认。
- 不要为了拼完整展示页试探非 public / 非黄金路径的组合搜索工具，也不要用 `page_size=1` 连续翻页重取同一个列表。展示层补全不能比业务查询本身更重。
