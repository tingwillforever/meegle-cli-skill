# Workflow

direct MCP 下的流程路径只使用 public workflow tools。

## 默认路径

### 读取当前流程状态

- `meegle.workflow.query`

用途：

- 确认当前节点 / 当前状态
- 拿到可流转信息
- 判断是 node flow 还是 state flow

### 查询必填

- `meegle.workflow.requiredInfo`

用途：

- 确认目标节点 / 目标状态变更所需字段

### 状态流

默认顺序：

1. `meegle.workflow.query`
2. `meegle.workflow.requiredInfo`
3. `meegle.workflow.stateChange`
4. `meegle.workflow.query` 回读

状态流写操作的完整 SOP 见 [sop-transition-state.md](sop-transition-state.md)。`transition_id` 必须来自 `meegle.workflow.query` 返回，不要从状态名或历史样例猜。

### 节点流

默认顺序：

1. `meegle.workflow.query`
2. `meegle.workflow.requiredInfo`
3. `meegle.workflow.nodeOperate`
4. `meegle.workflow.query` 回读

节点流写操作的完整 SOP 见 [sop-transition-node.md](sop-transition-node.md)。`node_id` 必须来自 `meegle.workflow.query` 返回；节点表单字段、节点负责人和节点排期不要混用工作项字段更新。

### 节点更新

只更新节点元信息时：

- `meegle.workflow.nodeUpdate`

## 风险点

- 不要在不知道 `node_id` / `transition_id` 的情况下猜写
- 节点排期和工作项排期不是同一 shape
- 返回成功不等于业务状态已正确变化，必须回读
- 必填人员、排期、枚举、关联工作项缺值时要询问用户，不能自行填充
- hard-block 字段见 [error-handling.md](error-handling.md)，遇到时停止并说明需要页面处理
- 权限不足时停止，不重试
