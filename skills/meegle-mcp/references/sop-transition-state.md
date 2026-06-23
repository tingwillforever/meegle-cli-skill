# SOP: State Workflow Transition

本 SOP 用于 direct MCP 下状态流工作项的状态变更。仅适用于状态流；节点流读 [sop-transition-node.md](sop-transition-node.md)。

## 前置建模

流转前先明确：

- `project_key`
- `work_item_type_key`
- `work_item_id`
- 当前状态
- 目标状态
- `transition_id`
- 必填字段
- readback 方式

## 执行顺序

1. `meegle.workitem.get`
   - 确认目标工作项存在。
2. `meegle.workflow.query`
   - 读取当前状态和可用 transitions。
   - 从返回中匹配目标状态，取得 `transition_id`。
   - `transition_id` 不能猜。
3. `meegle.workflow.requiredInfo`
   - 查询目标 transition 所需字段。
   - 遇到 hard-block 字段时停止。
4. `meegle.workflow.stateChange`
   - 只在 transition 和必填字段明确后执行。
5. `meegle.workflow.query`
   - 回读状态，确认是否已变更。

## 目标状态匹配

- 用户指定目标状态名：从可用 transitions 中精确或唯一模糊匹配。
- 用户说“下一步”：如果只有一个可用 transition 才自动选择。
- 多个候选：列出目标状态让用户选。
- 当前状态没有可用 transition：停止。

## 字段补充

- 人员字段缺失时必须询问，不自动填当前用户。
- 枚举字段列候选让用户选。
- 排期/日期字段必须由用户给出日期范围。
- 字段值 shape 参考 [field-value-format.md](field-value-format.md)。

## 停止条件

- 目标 transition 不存在。
- 当前状态是终态。
- 必填字段不可 API 写入。
- 权限不足。
- 回读状态未变化。

## 输出

流转后输出：

- 原状态
- 目标状态
- 执行结果
- 回读后的当前状态
- 未完成或被阻塞的原因
