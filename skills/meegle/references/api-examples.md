# Installed-CLI Examples

These examples are aligned to the current private installed CLI path.

## doctor

```bash
meegle doctor --format json
```

## workitem meta-types

```bash
meegle workitem meta-types --project-key PROJ --format json
```

## workitem create

```bash
meegle workitem create \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --name "测试需求" \
  --format json
```

## workitem get

```bash
meegle workitem get \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-ids '[12345]' \
  --select id,name,current_nodes,work_item_status,created_at \
  --format json
```

`workitem get` 支持 backend projection，`--select` 会映射为后端 `data.fields`。只想在返回后减少展示字段时，改用 `--output-select`。

## workitem update

```bash
meegle workitem update \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --update-fields '[{"field_key":"name","field_value":"新标题"}]' \
  --format json
```

## workitem search-filter

`--work-item-type-keys` 是复数，值为 JSON 数组字符串。

⚠️ `--created-at` / `--updated-at` 的 `start` / `end` 必须是**毫秒整数**（number 类型），不能是 ISO 字符串：
```bash
# 正确
--created-at '{"start":1771603200000,"end":1779379199000}'
# 错误（server 会报 expected number, received string）
--created-at '{"start":"2026-02-21T00:00:00+08:00","end":"..."}'
```

Python 换算：`int(datetime(..., tzinfo=tz).timestamp() * 1000)`

⚠️ `search-filter` **只支持内置维度**（业务线、时间、状态、优先级、tag），无法按自定义字段（如"所属项目"）过滤。需要自定义字段过滤时，改用 `search-by-params`（见下方示例）。

```bash
# 基础查询（返回完整字段）
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --page-size 10 \
  --format json

# 基础查询 + 本地展示裁剪（不改变后端请求）
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --page-size 10 \
  --output-select id,name,current_nodes,work_item_status,created_at \
  --format json

# 时间范围 + 业务线过滤
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --created-at '{"start":1771603200000,"end":1779379199000}' \
  --businesses '["BUSINESS_LINE_ID"]' \
  --page-size 200 \
  --format json
```

## workitem search-by-params

按结构化字段过滤，支持自定义字段。`page-size` 上限 50。

> 完整的 param_key 列表、operator 枚举、value 格式规范见 [search-params-format.md](search-params-format.md)。

⚠️ 关联字段（`work_item_related_select`）的 value 是**数字 ID**（number 类型），不是字符串。ID 需先查对应工作项类型获取，见 [search-params-format.md](search-params-format.md) 的「关联字段 ID 查找 SOP」。

`search-by-params` 支持 backend projection。默认用 `--select id,name,...` 限制后端返回字段；`--fields` 仅作为 API-native compatibility input，不能与 `--select` 同时使用。

```bash
# 时间范围 + 业务线 + 自定义关联字段（所属项目）+ 排除已完成状态
meegle workitem search-by-params \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --search-group '{
    "conjunction": "AND",
    "search_params": [
      {"param_key": "business", "operator": "HAS ANY OF", "value": ["BUSINESS_LINE_ID"]},
      {"param_key": "created_at", "operator": ">", "value": 1771603200000},
      {"param_key": "created_at", "operator": "<", "value": 1779379199000},
      {"param_key": "work_item_status", "operator": "HAS NONE OF", "value": ["Finished"]},
      {"param_key": "CUSTOM_FIELD_KEY", "operator": "HAS ANY OF", "value": [RELATED_WORKITEM_ID]}
    ],
    "search_groups": []
  }' \
  --select id,name,work_item_status,created_at \
  --page-size 50 \
  --format json
```

字段 key 查找：`workitem meta-fields --project-key PROJ --work-item-type-key TYPE_KEY --format json | jq '[.data[] | {field_key, field_name, field_type_key}]'`

## view items

```bash
meegle view items \
  --project-key PROJ \
  --view-id VIEW_ID \
  --page-size 20 \
  --output-select data.name,data.view_id,data.work_item_id_list \
  --format json
```

`view items` 不支持 backend projection。传 `--select` 会直接失败；若只是想减少本地展示字段，使用 `--output-select data.xxx`。

## comment add

```bash
meegle comment add \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --content "评论内容" \
  --format json
```

## workflow list-state-transitions

```bash
meegle workflow list-state-transitions \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```

## subtask create

```bash
meegle subtask create \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id NODE_ID \
  --name "子任务" \
  --format json
```

## subtask update

```bash
meegle subtask update \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id NODE_ID \
  --task-id TASK_ID \
  --note "更新备注" \
  --format json
```

## subtask operate

```bash
meegle subtask operate \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id NODE_ID \
  --task-id TASK_ID \
  --action confirm \
  --format json
```

## release deploy-task-prepare

```bash
meegle release deploy-task-prepare \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --appName APP_NAME \
  --format json
```

## release deploy-task-list

```bash
meegle release deploy-task-list \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --format json
```

## release deploy-task-execute

```bash
meegle release deploy-task-execute \
  --project-key PROJ \
  --release-id RELEASE_ID \
  --recordIDs RECORD_ID_1 \
  --recordIDs RECORD_ID_2 \
  --format json
```

## workitem cleanup

当前 public CLI 不暴露工作项删除命令。临时验证工作项需要清理时，先向用户说明不能通过当前 CLI 自动删除，并让用户在 web 端或已批准的专用清理流程中处理。
