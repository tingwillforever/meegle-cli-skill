# Search Params Format

本文件定义 direct MCP 下 `meegle.workitem.search.byParams` 的结构化查询规则。它迁移 CLI `search_params` 语义，但参数应按 MCP tool schema 传结构化对象，不按 shell JSON 字符串思考。

## SearchGroup

复杂查询先建模：

```text
查询主体：
筛选锚点：
过滤条件：
展示字段：
```

`search_group` 表达过滤条件，常见结构为：

```json
{
  "conjunction": "AND",
  "search_params": [
    {"param_key": "work_item_status", "operator": "HAS ANY OF", "value": ["state_key"]}
  ]
}
```

具体字段名以 MCP schema 和 `meegle.workitem.meta` 返回为准。

## 固定参数

| 语义 | `param_key` | value 来源 |
|---|---|---|
| 工作项 ID | `id` | 用户给定或 lookup 返回 |
| 状态 | `work_item_status` | 字段元数据中的 state value |
| 创建时间 | `created_at` | 毫秒时间戳区间 |
| 更新时间 | `updated_at` | 毫秒时间戳区间 |
| 创建者 | `created_by` | `meegle.user.search` / `meegle.user.query` |

## 自定义字段

- `param_key` 使用字段 key，不使用字段中文名。
- 枚举、人员、关联字段的 value 必须来自元数据或 lookup。
- 关联字段 value 使用被关联工作项数字 ID 数组。

## Operator

常用 operator：

- `=`
- `!=`
- `HAS ANY OF`
- `HAS NONE OF`
- `BETWEEN`
- `IS EMPTY`
- `IS NOT EMPTY`

不要把在线文档中的示例 operator 机械套到所有字段；以当前 MCP schema、字段类型和已验证路径为准。

## 关联字段过滤 SOP

1. 用 `meegle.workitem.meta` 找到关联字段 key。
2. 用 [field-value-extras.md](field-value-extras.md) 解析被关联工作项 ID。
3. 构造 `search_group`：

```json
{
  "conjunction": "AND",
  "search_params": [
    {"param_key": "CUSTOM_FIELD_KEY", "operator": "HAS ANY OF", "value": [123456]}
  ]
}
```

`value` 是数字 ID 数组，不是标题字符串。

不要在这条路径前后插入配置资源、资源库、关系列表或 agent planning 探测。`space.types -> workitem.search.filter/get -> workitem.meta -> workitem.search.byParams` 已经是关联字段查询的完整黄金路径。

如果黄金路径中的某个 canonical public tool 在当前宿主不可调用，停止并报告缺失工具；不要用租户、配置、视图写入、创建、删除、脚本/REPL、admin 或 dummy 参数调用去发现工具名或替代查询。

关联字段过滤任务的第一条 Meegle tool call 应是 `meegle.space.types`。不要先做 `__tool_probe__` 或无关工具探活；黄金路径上的第一个只读调用本身就是最小验证。

## 成本规则

- 不要为了格式化重跑同一查询。
- 已唯一确认字段 key 和锚点 ID 时，直接执行最终查询。
- 查询返回为空时，先检查字段 key、类型 key、operator、value shape，不要立刻扩大权限或全量扫描。
- 不要把写入/删除/管理类工具当作查询 schema 探测手段。
