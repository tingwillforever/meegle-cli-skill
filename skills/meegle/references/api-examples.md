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
  --work-item-ids 12345 \
  --format json
```

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

`--work-item-type-keys` 是复数，值为 JSON 数组字符串。只需摘要时加 `--select` 投影，避免大响应体。

```bash
# 基础查询（返回完整字段）
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --page-size 10 \
  --format json

# 摘要查询（推荐：只取常用顶层字段 + 优先级）
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --work-item-name "关键词" \
  --page-size 10 \
  --select 'id,name,current_nodes,work_item_status,created_at,updated_at' \
  --format json
```

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

## workitem remove

```bash
meegle workitem remove \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```
