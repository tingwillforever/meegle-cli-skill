# 视图辅助命令

## Private CLI 差异

| upstream | private installed CLI |
|---|---|
| `view list` | `view list` |
| `view items` | `view items` |
| `view create-fixed` / `view update-fixed` | 当前不作为默认 skill 路径 |
| `view list-multi-project-workitems` | 当前 public CLI 不暴露，按需另行评审 |

视图 URL 路由先看 [url-kinds.md](url-kinds.md)。不要从 URL path 推断视图类型；必须先用 `view list` 读取 `view_type`。

---

## view list

列出空间和工作项类型下的视图配置，返回 `view_id`、名称和 `view_type`。

```bash
meegle view list \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json
```

`view_type` 只用于选择后续路径，不要仅凭 URL 中的 `storyView` / `multiProjectView` 判断。

## view items

读取固定视图或系统列表视图下的工作项。通常用于 `view_type=0` 或 `view_type=2`。

```bash
meegle view items \
  --project-key PROJ \
  --view-id VIEW_ID \
  --page-size 50 \
  --format json
```

当前 public CLI 不暴露 `view panoramic-items`。如果后续确认需要条件视图读取能力，应单独评审后再开放。

## view delete

删除固定视图或条件视图。固定视图和条件视图共用同一接口，通过 `view_id` 区分。

```bash
meegle view delete \
  --project-key PROJ \
  --view-id VIEW_ID \
  --format json
```

## view create-condition

创建条件视图。`--search-group` 传 JSON 对象，结构见下方。

```bash
meegle view create-condition \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --name '视图名称' \
  --search-group '{"conjunction":"AND","search_params":[...]}' \
  --format json
```

**⚠️ `project_key` 必须是 UUID（如 `678f4f4845d3ddb9484881d9`），不能是 simple_name（如 `cbg_product_develop`）。** CLI 会自动解析，但直接调用原始 API 时需注意。

`--search-group` 不传则创建空条件视图。

## view update-condition

更新条件视图的名称或筛选条件。需要同时传 `--work-item-type-key`。

```bash
meegle view update-condition \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --view-id VIEW_ID \
  --search-group '{"conjunction":"AND","search_params":[...]}' \
  --format json
```

---

## search_group 结构

```json
{
  "conjunction": "AND",
  "search_params": [
    {
      "param_key": "字段key或固定参数key",
      "value": ["值1", "值2"],
      "operator": "HAS ANY OF"
    }
  ]
}
```

操作符枚举见 [search-params-format.md](search-params-format.md)。

### 常用固定参数

| 参数名 | param_key | 支持操作符 | value 格式 | 说明 |
|---|---|---|---|---|
| 进行中节点 | `current_nodes` | `=`、`!=`、`HAS ANY OF`、`HAS NONE OF`、`CONTAINS`、`NOT CONTAINS` | **节点名称**列表 | 从"获取流程模板配置详情"接口获取，**不是 state_key** |
| 流程节点（含历史） | `all_states` | 同上 | **节点名称**列表 | |
| 业务线 | `business` | `=`、`!=`、`HAS ANY OF`、`HAS NONE OF`、`IS NULL`、`IS NOT NULL` | 业务线 ID 列表 | 从 `meegle space business-lines` 获取 |
| 工作项状态 | `work_item_status` | `=`、`!=`、`HAS ANY OF`、`HAS NONE OF` | `state_key` 列表 | 来自 `meegle workitem meta-fields` 的 `options[].value` |
| 模板 | `template` | `=`、`!=`、`HAS ANY OF`、`HAS NONE OF`、`IS NULL`、`IS NOT NULL` | 模板 ID 列表 | |
| 更新时间 | `updated_at` | `=`、`!=`、`<`、`>`、`<=`、`>=` | UTC 格式字符串 | 如 `2024-09-01T00:00:00+07:00` |

### 普通字段

`param_key` 为字段的 `field_key`，`value` 格式与字段类型对应（user 类型传 user_key 列表，select 类型传 option value 列表等）。

### 示例：测试业务线 + 我负责 + 已完成状态

```json
{
  "conjunction": "AND",
  "search_params": [
    {"param_key": "business", "value": ["678f4f4907926543018acd93"], "operator": "="},
    {"param_key": "owner", "value": ["7457914056381416309"], "operator": "HAS ANY OF"},
    {"param_key": "work_item_status", "value": ["-a2LFTw3o"], "operator": "HAS ANY OF"}
  ]
}
```

### 示例：筛选处于"需求完成"节点的工作项

```json
{
  "conjunction": "AND",
  "search_params": [
    {"param_key": "current_nodes", "value": ["需求完成"], "operator": "HAS ANY OF"}
  ]
}
```

