# 工作流辅助命令

工作流流转之前用来查询可流转方向、必填项、节点字段配置的辅助命令。核心流转命令（`workflow transition` 节点流 / `workflow transition-state` 状态流 / `workflow update-node`）见 SKILL.md 主文件 + `sop-transition-node.md` / `sop-transition-state.md`。

## 与 upstream 差异

| upstream 命令 | 本地 CLI | 说明 |
|---|---|---|
| `workflow meta-node-fields` | 不支持 | MCP 无对应工具，用 `workflow list-state-transitions` 返回的 `workflow_nodes[].fields` 替代 |

其余 workflow 命令已与 upstream 完全对齐。

---

## workflow list-state-transitions

查询工作项当前的完整工作流状态，包含所有节点 / 状态、当前位置、可流转方向。状态流流转前必须先调用此命令拿 `transition_id`。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `--project-key` | string | 是 | 空间 key |
| `--work-item-type-key` | string | 是 | 工作项类型 UUID（来自 `workitem meta-types`） |
| `--work-item-id` | number | 是 | 工作项 ID |
| `--flow-type` | number | 否 | 0=节点流，1=状态流；不传由后端自动检测 |

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key 678de79dc62484dbfcc76150 \
  --work-item-id 12345 \
  --format json
```

返回：

- 节点流：`workflow_nodes[]`，每个节点的 `id` / `name` / `status` / `owners`
- 状态流：`connections[]`（含 `source_state_key` → `target_state_key`）
- 节点字段定义嵌在 `workflow_nodes[].fields` 里（替代 `meta-node-fields`）

---

## workflow list-state-required

查询特定节点 / 状态流转所需的必填字段。`workflow transition` confirm / `workflow transition-state` 之前如果报必填项缺失，用它来定位。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `--project-key` | string | 是 | 空间 key |
| `--work-item-id` | number | 是 | 工作项 ID |
| `--work-item-type-key` | string | 否 | 工作项类型 UUID（不传时由后端推断） |
| `--node-id` | string | 否 | 节点流的 `node_id` 或状态流的目标 `state_key` |
| `--mode` | string | 否 | 默认查所有必填；传 `unfinished` 仅返回未完成的必填项 |

```bash
meegle workflow list-state-required \
  --project-key PROJ \
  --work-item-id 12345 \
  --node-id node_dev \
  --mode unfinished \
  --format json
```

返回：`required_fields[]` 含 `field_key` / `field_name` / 当前值 / 是否已满足。

---

## 节点字段配置（替代 meta-node-fields）

`workflow update-node` 修改节点的 owners / schedule / 自定义字段前需要确认合法 `field_key`。节点字段定义嵌在 `workflow list-state-transitions` 返回的 `workflow_nodes[].fields` 里。

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json | jq '.data.workflow_nodes[] | select(.id=="node_dev") | .fields'
```

---

## 常见用法

### 节点流：完成当前节点

```bash
# 1. 查节点
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json | jq '.data.workflow_nodes[] | {id, name, status, owners}'

# 2. 检查必填项
meegle workflow list-state-required \
  --project-key PROJ \
  --work-item-id 12345 \
  --node-id node_dev \
  --mode unfinished \
  --format json

# 3. confirm 节点
meegle workflow transition \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id node_dev \
  --action confirm \
  --format json
```

### 状态流：状态切换

```bash
# 1. 查可用 transitions
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json | jq '.data.connections[]'

# 2. 拿到目标 state_key 后，检查必填
meegle workflow list-state-required \
  --project-key PROJ \
  --work-item-id 12345 \
  --node-id target_state_key \
  --format json

# 3. 切换状态
meegle workflow transition-state \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --transition-id TRANS_ID \
  --format json
```
