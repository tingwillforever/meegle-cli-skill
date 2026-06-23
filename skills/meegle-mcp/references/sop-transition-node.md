# SOP: Node Workflow Transition

本 SOP 用于 direct MCP 下节点流工作项的节点完成、回滚和节点字段更新。状态流读 [sop-transition-state.md](sop-transition-state.md)。

## 前置建模

节点操作前先明确：

- `project_key`
- `work_item_type_key`
- `work_item_id`
- 当前节点
- 目标节点或动作
- `node_id`
- 必填节点字段、角色负责人、排期
- readback 方式

## 执行顺序

1. `meegle.workitem.get`
   - 确认目标工作项存在。
2. `meegle.workflow.query`
   - 读取节点列表、当前节点、节点字段、可执行动作。
   - `node_id` 必须来自返回，不使用节点名称猜。
3. 必填项预检。
   - 从 workflow 返回或 `meegle.workflow.requiredInfo` 汇总缺失字段。
   - 人员、排期、枚举、关联工作项缺值必须让用户提供或确认。
4. `meegle.workflow.nodeUpdate`
   - 只在需要补节点负责人、节点排期或节点字段时使用。
5. `meegle.workflow.nodeOperate`
   - 执行 confirm / rollback 等动作。
6. `meegle.workflow.query`
   - 回读节点状态。

## 必填项处理

执行前要把缺失项汇总给用户确认。不要自行填充人员、排期、枚举或关联工作项。

可默认建议但仍需用户确认：

- 文本
- 数字
- 布尔值

不可 API 写入字段按 [error-handling.md](error-handling.md) hard-block 停止。

## 字段 shape

- 节点排期和工作项排期不是同一 shape。
- 节点负责人和节点排期优先使用节点专用参数。
- 节点表单字段使用 workflow tool 接受的结构化字段参数。
- 不要用 `meegle.workitem.update` 更新节点表单字段。

## 批量节点操作

用户要求“全部节点”时按节点顺序串行处理：

- 每个节点独立 readback。
- 某个节点被 hard-block 时，停止该节点并继续汇总结果；是否继续其它节点取决于用户意图和风险。
- 最终输出每个节点的结果。

## 停止条件

- 找不到 `node_id`。
- 必填字段不可 API 写入。
- 用户未提供必需人员、排期或关联工作项。
- 权限不足。
- 回读节点状态未变化。
