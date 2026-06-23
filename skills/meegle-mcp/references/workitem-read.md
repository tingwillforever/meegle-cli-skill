# Workitem Read

本文件定义 direct MCP 下的工作项读取主路径。

## 读路径建模

先在内部明确：

```text
查询主体：
筛选锚点：
过滤条件：
目标输出：
```

主体是工作项时：

- 工作项类型发现走 `meegle.space.types`
- 字段发现走 `meegle.workitem.meta`
- 最终展示字段、分页说明和 raw key 标注走 [result-display.md](result-display.md)

## 默认路径

### 1. 当前用户相关语义

需要“我相关 / 我负责 / 我参与”时，先拿当前用户：

- `meegle.user.query`
  - `data.user_keys=["current_login_user()"]`

不要猜 user_key。

如果用户已经给了空间锚点，且目标只是“我参与 / 我负责”的工作项读取，默认顺序应当是：

1. `meegle.user.query`
2. `meegle.space.types`
3. `meegle.workitem.search.filter` 或 `meegle.workitem.search.byParams`

这条路径是黄金路径。即使用户给的是 `cbg_product_develop` 这类 simple name，只要 `meegle.space.types` 能直接接受该值，就继续沿用它作为当前读接口锚点，不要先转换成底层 `project_key`。

一旦 `meegle.space.types` 成功返回目标工作项类型，空间锚点就已经足够用于本次读路径；直接进入最终查询，不要再做空间发现。

在这条默认路径里，不要先调用下列工具做无关探测：

- `meegle.space.detail`
- `meegle.space.teamMembers`
- `meegle.space.list`
- `meegle.user.search`
- 智能搜索类路径
- 跨空间搜索类路径

只有当 `meegle.space.types` 或目标查询明确返回 project not found / scope mismatch，且当前 session 没有唯一默认 `projectKeys` 可用时，才补做空间详情确认；确认后仍优先回到 `space.types -> search.filter/byParams`，不要用跨空间搜索代替已知空间查询。

### 2. 类型发现

用户已给 `project_key` 时：

- 直接用该 `project_key`

当前 session 只有一个 `projectKeys` 时：

- 直接把这个唯一值当默认 `project_key`
- 不要为了“确认空间”先跑 `meegle.space.detail` / `meegle.space.list`
- 不要再次追问用户“是否还是这个空间”

用户给的是 `cbg_product_develop` 这类可读空间标识，且当前 session 没有唯一默认空间时：

- 先把它当作空间锚点直接走读路径
- 只有当目标读接口明确拒绝，或当前 session 暴露多个 `projectKeys` 且无法唯一判定时，才补做空间详情确认
- 不要在回复里把这类锚点直接表述成“真实 project_key”，除非你已经显式确认过

用户没给空间时：

- 可用 `meegle.space.list` 做一次发现

类型发现一律走：

- `meegle.space.types`

从结果中取真实 `type_key`，不要把 `api_name` 当成 type key 试探。

### 3. 字段发现

需要下列任一内容时，先读 `meegle.workitem.meta`：

- 状态中文映射
- 负责人字段 key
- 优先级 / 业务线 / 关联字段 key
- 关联字段 value 的合法类型

`meegle.workitem.meta` 返回的是 direct MCP 当前暴露的字段元数据事实源；不要再假设 CLI 的 `meta-fields` / `meta-create-fields` 区分。

### 4. 最终查询选择

- 内置维度、小页读取、模糊名称：
  - `meegle.workitem.search.filter`
- 自定义字段、关联字段、字段级人员语义、复杂 AND/OR：
  - `meegle.workitem.search.byParams`
- 已知 ID 批量读取：
  - `meegle.workitem.get`

## 关键规则

### 状态中文名

如果结果只有底层 `state_key`，状态中文名必须来自 `meegle.workitem.meta` 中 `work_item_status.options[]` 的 `value -> label` 映射。

### 负责人

如果结果里负责人只有 raw `user_key`：

- 用户允许 raw 时，可直接展示 raw key
- 用户要求可读化时，再用 `meegle.user.query` 批量回填当前页唯一 key

### 关联字段过滤

关联字段的 `value` 必须使用被关联工作项的数字 ID，不是标题字符串。

常见做法：

1. 先在锚点类型范围内定位目标工作项 ID
2. 再在目标主体类型上用 `meegle.workitem.search.byParams`

构造复杂 `search_group` 前读 [search-params-format.md](search-params-format.md)。如果关联锚点来自名称而不是 ID，先读 [field-value-extras.md](field-value-extras.md) 做名称到 ID 解析。

关联字段查询不需要配置资源或资源库 discovery。已经通过 `meegle.space.types` 确认工作项类型时，直接用 `meegle.workitem.search.filter` / `meegle.workitem.get` 定位锚点 ID，再用 `meegle.workitem.meta` 读取主体类型字段元数据，最后 `meegle.workitem.search.byParams` 查询；不要插入非 public/full preset 探测工具。

这条路径也不需要 Meegle 业务工具发现式探测。Agent / Codex 宿主若提供非业务工具发现机制，只能用它查 exact canonical tool name；如果 `meegle.space.types`、`meegle.workitem.search.filter` / `meegle.workitem.get`、`meegle.workitem.meta` 或 `meegle.workitem.search.byParams` 在当前宿主中不可调用，停止并报告缺失的 public tool。不要用租户、配置资源、视图写入、创建/删除、脚本/REPL、admin 或 dummy 参数调用去“验证”工具面。

关联字段读取任务的第一条 Meegle tool call 应是 `meegle.space.types`。不要先调用 `__tool_probe__`、删除/写入类工具或无关读工具来探活；如果担心工具不可用，直接调用 canonical 只读工具本身，由其返回决定是否停止。

### 默认展示合同

默认工作项列表按 [result-display.md](result-display.md) 输出，不要只输出 ID 和名称。若当前页已经返回状态/节点、负责人、创建时间或分页信息，应直接整理成有界展示页，不要回复“若你要我可以继续整理”。

核心要求：

- 默认列：`ID`、`名称`、`当前状态/节点`、`当前负责人`、`创建时间`。
- 如果返回 `pagination.total`，说明“共命中 N 条，当前展示 M 条”。
- 当前状态优先用本轮已读取的 `meegle.workitem.meta` 映射；否则可用 `current_nodes[].name`；再否则标注 raw `state_key`。
- 当前负责人从 `fields[]` 的 `current_status_operator` 读取；可复用本轮 `meegle.user.query` 已解析的当前用户姓名。只有当前页仍是 raw key 且用户未要求 raw 时，最多一次 `meegle.user.query` 批量回填。
- `created_at` / `updated_at` 是毫秒时间戳。当前页对象有 `created_at` 时必须展示 `创建时间` 列；能确定性格式化时用 `Asia/Shanghai`，不能确定性转换时展示毫秒或 ISO，不要心算，也不要把“带上创建时间”留到下一轮。

### 只读成本预算

- 同一工作项类型最多读取一次字段元数据。
- 同一最终查询不要为了格式化重复执行。
- 查询成功后只做本地映射、裁剪、排序和摘要。
- 如果用户要更多页或导出，等用户明确要求再继续翻页。
- 同一展示页最多一次人员回填查询；当前页数据已够时直接输出，不做“先问是否整理”的二段式回复。
- 最终查询成功后，不要为了展示把查询语义改写成另一个条件重新查。例如“我参与”用 `user_keys` 命中后，不能再改用 `owner` 或负责人字段查询来生成展示页；需要补字段时只能按当前页 ID 做一次 `meegle.workitem.get`。
- 不要为了展示完整性试探非 public / 非黄金路径的组合搜索工具，也不要把同一 `search.filter` 查询拆成 `page_size=1` 多次翻页。若宿主展示层截断了大回包，先输出当前已确认字段和总数，再说明未确认字段。

### 不要做的事

- 不要重复读取同一份字段元数据
- 不要把名称字符串直接塞进关联字段过滤
- 不要把“我参与”误判成空间内全量对象
- 不要在 direct MCP 里继续引用 CLI `url decode` / `inspect`
- 不要把业务字段当成稳定顶层字段；除 `id`、`name`、`work_item_status`、`current_nodes`、时间和类型等稳定字段外，业务字段默认从字段容器读取
- 不要为了发现 MCP tool 名或参数 schema 调用无关业务工具；canonical public tool 缺失时应暴露 capability gap，而不是通过失败的写入/删除/管理类调用绕路
