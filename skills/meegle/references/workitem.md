# 工作项元数据命令

查询工作项类型、字段、角色配置的辅助命令。在 `workitem create` / `workitem update` / `workitem get` 之前用来确认合法 key。

所有 workitem meta 命令已与 upstream 完全对齐：
- `workitem meta-types` — 列出空间下所有工作项类型
- `workitem meta-fields` — 列出字段配置（可按工作项类型过滤）
- `workitem meta-roles` — 列出流程角色配置
- `workitem meta-create-fields` — 获取创建工作项所需的元数据

---

## 工作项对象结构

`workitem get` / `workitem search-filter` 返回的工作项对象有两层字段：

**顶层字段**（直接访问，不在 `fields[]` 里）：

| 字段 | 说明 |
|------|------|
| `id` | 工作项 ID |
| `name` | 标题（即工作项名称） |
| `current_nodes` | 当前所在节点数组，可能为空 `[]`；每项含 `id`、`name`、`owners` |
| `work_item_status` | 当前状态对象，含 `state_key`（如 `"started"`、`"Finished"`）；**无 display name 字段**。展示给用户时**默认显示中文名称**：用 `workitem meta-fields` 取 `work_item_status` 字段的 `options[]`，建立 `value → label`（注意是 `label` 不是 `name`）映射后回填。同一类型只需查一次。 |
| `created_at` | 创建时间（毫秒时间戳） |
| `updated_at` | 更新时间（毫秒时间戳） |
| `created_by` | 创建人 user_key |
| `work_item_type_key` | 工作项类型 UUID |

**`fields[]` 数组**：自定义字段，通过 `field_alias` 或 `field_key` 访问，例如优先级、负责人、截止日期等。

> 取标题用 `item['name']`，不要在 `fields[]` 里找。`current_nodes` 可能为空数组，访问前先判断长度。

---

## 关联字段过滤

`work_item_related_select` 类型字段（如"所属项目"）在 `search-by-params` 中过滤时：

1. **value 是被关联工作项的数字 ID**（number 类型，不是字符串）
2. **ID 不是直接已知的**，需先查出来：用 `workitem search-filter` 查对应工作项类型（如 `pdm` 查所属项目），按名称匹配取 `id`
3. 字段 key 用 `workitem meta-fields` 查，按 `field_name` 定位，取 `field_key`

```bash
# Step 1：查所属项目 ID（pdm 类型，按名称匹配）
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["678db77d0ddcc724f5409bbf"]' \
  --format json | jq '[.data[] | {id, name}]'

# Step 2：查字段 key
meegle workitem meta-fields \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json | jq '[.data[] | select(.field_type_key=="work_item_related_select") | {field_key, field_name}]'

# Step 3：用数字 ID 过滤
# search-by-params --search-group 中：
# {"param_key": "CUSTOM_FIELD_KEY", "operator": "HAS ANY OF", "value": [PROJECT_ID]}
#                                                                         ↑ 数字，不加引号
```

---

## workitem meta-types

列出空间下所有工作项类型。用户描述模糊时用此命令确认合法 `type_key`。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `--project-key` | string | 是 | 空间 `project_key` |

```bash
meegle workitem meta-types --project-key PROJ --format json
```

返回：`type_key`（UUID）、`name`（中英显示名）、`api_name`（如 `story_new`）。**写命令必须用 `type_key` UUID，不要用 api_name。**

---

## workitem meta-create-fields

获取指定工作项类型的创建元数据候选：字段名 / 字段类型 / 枚举可选值 / 模板等。`workitem create` 缺模板报错时也用它查 `template` 字段。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `--project-key` | string | 是 | 空间 `project_key` |
| `--work-item-type-key` | string | 是 | 工作项类型 UUID（来自 `workitem meta-types`） |

```bash
meegle workitem meta-create-fields \
  --project-key PROJ \
  --work-item-type-key 678de79dc62484dbfcc76150 \
  --format json
```

返回结构（节选）：

- `.data[]` —— 扁平字段数组；每个元素包含 `field_key` / `field_name` / `field_type_key` / `is_required` / `options[]`
- 模板不是顶层 `templates[]`，而是字段数组中 `field_key == "template"` 的那一项；其 `options[]` 就是可选模板

⚠️ 重要边界：

- `meta-create-fields` 是创建页元数据；其中 `is_required == 1` 表示创建页必填字段
- `workitem create` 前必须为所有 `is_required == 1` 字段准备非空值
- 如果某个必填字段在 `workitem create` 中返回 `field [xxx] is illegal`，这是元数据与 create API 的契约不一致
- 不要删除必填字段绕过创建；应停止并报告该契约问题

字段写入格式见 `sop-create-workitem.md` / `sop-update-workitem.md`。具体命令参数仍以 `meegle inspect workitem.create --format json` 和 `meegle inspect workitem.update --format json` 为准。

---

## 常见用法

```bash
# 1. 不知道空间用啥类型 — 列出来
meegle workitem meta-types --project-key PROJ --format json

# 2. 拿到 type_key 后，看字段定义
meegle workitem meta-create-fields \
  --project-key PROJ \
  --work-item-type-key 678de79dc62484dbfcc76150 \
  --format json | jq '.data[] | {field_key, field_name, field_type_key, is_required}'

# 3. 找枚举字段的合法 option
meegle workitem meta-create-fields \
  --project-key PROJ \
  --work-item-type-key 678de79dc62484dbfcc76150 \
  --format json | jq '.data[] | select(.field_key=="priority") | .options'
```

