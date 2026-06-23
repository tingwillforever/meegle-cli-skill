# Field Value Extras

本文件覆盖字段值构造中的高风险补充场景，重点是“名称 -> ID”解析。

## 关联工作项名称转 ID

关联字段过滤或写入时，value 必须使用被关联工作项的数字 ID，不使用标题、URL 片段或字符串 ID。

只使用工作项类型、工作项搜索和字段元数据路径即可完成关联字段解析。不要为了“发现关联资源”先探测配置资源、资源库、关系列表或非 public/full preset 工具；这些探测既不是 public MCP 黄金路径，也容易改变权限边界。

不要把“工具名发现”伪装成关联字段解析步骤。当前宿主若没有暴露 canonical public read tools，应停止并报告缺口；不要调用租户、配置、视图写入、创建、删除、脚本/REPL 或 dummy 参数探测来替代 `space.types -> workitem.search.filter/get -> workitem.meta -> workitem.search.byParams`。

当任务是“按关联工作项名称查目标工作项”时，第一条 Meegle tool call 应直接是 `meegle.space.types`。不要先用 `__tool_probe__`、删除视图、创建工作项、配置资源查询或脚本枚举来确认 MCP 是否可用。

默认流程：

1. 确认目标字段。
   - 用 `meegle.workitem.meta` 找到字段 key 和 `field_type_key`。
   - 只对可搜索或可写的关联字段继续。
2. 定位被关联工作项。
   - 用户给 ID：直接作为候选 ID，但仍要按需 `meegle.workitem.get` 核验。
   - 用户给名称：优先用 `meegle.workitem.search.filter` 小页查询。
   - 需要字段级条件时用 `meegle.workitem.search.byParams`。
3. 处理候选。
   - 唯一候选：使用其数字 ID。
   - 多个候选：展示 ID、名称、状态等最小信息让用户选择。
   - 无候选：停止并说明无法解析。
4. 构造字段值或查询条件。
   - 单选关联：单个数字 ID。
   - 多选关联：数字 ID 数组。

## 防错规则

- 不要先裸查全类型再猜最近的一条。
- 不要调用配置资源、资源库或关系探测路径来寻找关联字段；关联字段事实源是 `meegle.workitem.meta` 返回的字段元数据。
- 不要调用写入、删除、视图配置修改、租户/admin、脚本/REPL 或 dummy 参数探测来发现工具面。
- 锚点类型已明确时，名称查询必须限定在该类型。
- 关联字段写入前排除当前工作项自身 ID，避免循环引用。
- 如果结果只返回字符串 ID，按 tool schema 要求转换；最终回答中说明使用的是工作项 ID。

## 与 search-by-params 的关系

当关联字段用于过滤时，`search_group` 中的 value 默认写成数字 ID 数组。详细结构见 [search-params-format.md](search-params-format.md)。
