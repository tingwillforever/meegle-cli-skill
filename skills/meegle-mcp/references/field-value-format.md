# Field Value Format

构造任何工作项字段值、流程补充字段或附件字段前，先根据 `meegle.workitem.meta` / `meegle.workflow.query` 返回的 `field_type_key` 选择 shape。不要凭历史 case、字段中文名或 CLI 字符串协议猜 value。

## 基本原则

- option value、人员 key、关联工作项 ID 都必须来自 MCP tool 返回。
- create/update 使用当前 MCP tool schema 的结构化参数；不要迁入 CLI 的 shell 转义或双重 stringify。
- 字段没有出现在当前类型元数据里时，停止或追问，不要拼 `field_*`。
- 复杂字段写入后必须 readback。

## 常见字段

| `field_type_key` | MCP value 规则 | 注意事项 |
|---|---|---|
| `text` / `multi_text` | 字符串 | 富文本 Markdown 语法按任务需要保留 |
| `number` | 数字或数字字符串，以 tool schema 为准 | 不要带单位 |
| `bool` | boolean | 不要用 `"是"` / `"否"` 猜 |
| `date` | 毫秒时间戳 | 默认按用户日期所在时区换算 |
| `schedule` | `{ "start_time": ms, "end_time": ms }` | 不要和节点排期的 `estimate_*` 字段混用 |
| `select` / `radio` | 来自 `options[]` 的 value，必要时保留 label | value 不同租户不同 |
| `multi_select` | 多个 option value 的数组或 schema 要求的对象数组 | 不要传 label 数组 |
| `tree_select` | 末级叶子 option value | 不满足层级时列候选让用户选 |
| `tree_multi_select` | 末级叶子 value 数组 | 不要传非叶子节点 |
| `user` | 单个 user key | 人名先用 `meegle.user.search` 解析 |
| `multi_user` | user key 数组 | 同名冲突时让用户确认 |
| `workitem_related_select` | 单个工作项数字 ID | 名称先解析成 ID |
| `workitem_related_multi_select` | 工作项数字 ID 数组 | 禁止写入当前工作项自身 ID |
| `link` | URL 字符串或 schema 要求对象 | 不要自行展开页面内容 |
| `file` / `multi_file` | 不走普通字段内联写入 | 用附件工具上传/删除 |

## 不可默认 API 写入

遇到下列类型时不要绕路写入：

- 投票类字段
- 计算字段
- `compound_field`
- `multi_user_compound_field`
- 页面专属节点结论/意见类字段

如这些字段是必填，停止并说明需要页面处理或管理员调整配置。

## 人员解析

- 已知 user key：直接使用。
- 已知 email / out_id：用 `meegle.user.query` 精确解析。
- 只有姓名：用 `meegle.user.search`，同名时展示候选并等待用户选择。

## 关联字段

关联字段值必须是工作项 ID。用户给名称或 URL 时：

1. 先定位被关联工作项类型。
2. 用 `meegle.workitem.search.filter` 或 `meegle.workitem.search.byParams` 找到候选。
3. 唯一命中才写入；多个候选让用户选。

详细 SOP 见 [field-value-extras.md](field-value-extras.md)。
