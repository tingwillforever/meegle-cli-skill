# View

direct MCP 下的视图路径与 CLI 的主要差异是：没有 URL decode，也没有 CLI output wrapper 语义。

## 读视图的前提

要读取视图，至少需要：

- `project_key`
- `work_item_type_key`
- `view_id`

如果用户给的是 `cbg_product_develop` 这类可读空间标识，先把它作为当前授权锚点直接走读路径。只要 `meegle.space.types` 或目标视图接口接受它，就继续沿用它；不要先用空间详情转换成底层 UUID。底层 UUID 在 public scope 下可能反而超出授权范围。

只有当目标接口明确拒绝 simple name，且当前接口确实要求底层 UUID 时，才补做空间详情或等价解析；解析后仍要确认新锚点在当前 MCP session 授权范围内。

如果只有 URL，而平台没有先把 URL 解析成这些结构化参数，就不能把它当作 direct MCP 默认可读场景。

## 视图配置发现

先用：

- `meegle.view.list`

用它确认：

- 目标视图是否存在
- `view_type`
  - `0` / `2`：system/fixed list
  - `1`：condition / panoramic

## 读取 fixed/system list 视图

默认顺序：

1. 已知空间锚点 / `work_item_type_key` / `view_id` 时，先 `meegle.space.types` 确认类型锚点；不要先 `space.detail` 把 simple name 改写成 UUID。
2. `meegle.view.list`
3. `meegle.view.fixItems`
4. 如需工作项详情，再 `meegle.workitem.get`

读取成功后只在同一份返回上整理标题、ID 和摘要；不要为了格式化重复读取同一个视图。如果第一次 `view.list` 已经确认目标 `view_id` 和 `view_type`，不要再调用第二次 `view.list`。

已知三元组读取视图时，不要先探测关系、关联工作项、跨空间搜索或 dummy work item 路径。视图读取的黄金路径就是类型发现后走 `view.list -> view.fixItems -> workitem.get`；无关探测失败只会污染结果并增加误判。

如果已经调用 `meegle.workitem.get` 展开工作项详情，最终回答按 [result-display.md](result-display.md) 展示工作项列：`ID`、`名称`、`当前状态/节点`、`当前负责人`、`创建时间`。如果只读取了 `work_item_id_list`，不要伪造尚未读取的标题、状态或负责人。

## condition / panoramic 视图

当前 public MCP 已暴露：

- `meegle.view.fixItems`

如果业务场景需要 condition view items：

- 先看当前平台是否明确允许使用 direct MCP 的条件视图读取路径
- 没有明确能力保证时，不要伪造与 CLI 等价的承诺
- 条件视图筛选不要使用未确认可搜索的字段；复杂条件先读 [search-params-format.md](search-params-format.md)

图表读取：

- 已知 chart id 且 public MCP 暴露图表读取能力时，可使用 `meegle.measure.chartData`
- 只有图表 URL 且平台没有结构化 `chart_id` 时，按 [runtime-boundary.md](runtime-boundary.md) 暴露 URL capability gap

## 视图写入

fixed view：

- `meegle.view.createFix`
- `meegle.view.updateFix`

condition view：

- `meegle.view.createCondition`
- `meegle.view.updateCondition`

删除：

- `meegle.view.delete`

这些都属于写操作，执行前要二次确认。
删除视图属于 destructive 操作，必须确认 `project_key`、`work_item_type_key`、`view_id` 和不可恢复影响。
