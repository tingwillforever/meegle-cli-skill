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

### 用户可读展示

对用户展示工作项查询结果时，默认做语义化回填，不直接输出原始 key：

- `work_item_status.state_key`：用 `workitem meta-fields` 中 `work_item_status.options[]` 建立 `value → label` 映射，默认显示中文状态名；只有排障时才附带原始 `state_key`
- `current_nodes[]`：直接显示节点 `name`
- `select` / `multi-select` / `tree-select` 等枚举字段：优先显示 `label`，不要把 `value` 直接展示给用户
- `business` / 业务线 ID：用 `meegle auth whoami --format json` 的 `business_line_names` 或 `meegle space business-lines` 返回名称回填
- 角色 key：用 `meegle workitem meta-roles --project-key PROJ --work-item-type-key TYPE_KEY --format json` 回填角色名称
- 人员 user_key：必要时用 `meegle user query --user-keys '["USER_KEY"]' --format json` 回填精确对象；若上下文明确是“空间下团队成员”，再用 `meegle team list-members --project-key PROJ --format json` 查看团队列表及其 `user_keys` / `administrators`，但不要把它当成空间成员全集

如果一时拿不到映射，先明确标注“原始 key”，不要把它误写成中文语义。

---

## 当前用户相关查询

当用户说“我的”“我参与的”“与我相关的”某类工作项时，不能直接查询该类型全量列表。

- 若使用 `workitem search-filter`，必须显式加 `--user-keys '["<meegle_user_key>"]'`。`--user-keys` 匹配 creator / follower / role owner，语义是“与这些用户相关的工作项”。
- 不带 `--user-keys` 的查询，只能解释为“空间内该类型工作项列表”，不能默认解释为“当前用户相关列表”。
- 若用户要求更严格的字段级人员语义，如“我负责的”“people 字段包含我”，改用 `workitem search-by-params` 的 `people` 条件或对应字段条件。
- 当前登录用户的 `meegle_user_key` 优先来自 `meegle auth whoami --format json`。

---

## 字段 projection 与本地输出裁剪

工作项读取场景里有三种容易混淆的字段选择能力：

| 能力 | 使用方式 | 适用场景 |
|---|---|---|
| Backend projection | `--select id,name,current_nodes,work_item_status` | 命令声明支持后端 projection，需要减少后端返回字段 |
| Local output projection | `--output-select id,name,current_nodes,work_item_status` | 只想减少本地展示字段，不改变后端请求 |
| API-native fields | `--fields '["id","name"]'` | 底层 API 兼容参数，仅在命令特定场景或排障时使用 |

当前默认 projection-capable 工作项命令：

- `workitem get`
- `workitem search-by-params`

规则：

- 准备使用 `--select` 时，先运行 `meegle inspect workitem.get --format json` 或 `meegle inspect workitem.search-by-params --format json`，确认 `projection.backend_select_supported == true`。
- 在上述命令上，默认用 `--select` 表达产品化字段 projection。
- 不要同时传 `--select` 与 `--fields`。
- `workitem search-filter` 主要用于内置维度过滤；它不声明 backend projection，传 `--select` 会直接报错。如果只是想少展示字段，用 `--output-select`。
- 排障时先用 `--dry-run` 查看 `.params.data.fields` 是否出现，确认 projection 已进入后端请求。
- verified command 的 dry-run 如果因为未知顶层参数直接失败，优先检查 flag 名、`--params` 顶层 key，或重新用 `inspect --format json` 对照当前命令面。
- 当前后端在 `workitem get` / `workitem search-by-params` 上主要会收敛 `fields[]` 自定义字段集合；`id`、`name`、`current_nodes`、`work_item_status`、`created_at` 等固定顶层字段仍可能按接口契约返回。

---

## 关联字段过滤

`workitem_related_select` / `work_item_related_select` 类型字段（如"所属项目"）在 `search-by-params` 中过滤时：

1. **value 是被关联工作项的数字 ID**（number 类型，不是字符串）
2. **ID 不是直接已知的**，需先查出来：先确定目标工作项类型，再按该类型的查询职责选命令
   - 基础名称匹配、内置维度过滤：用 `workitem search-filter`
   - 字段级/复杂条件查询，或当前授权/接口契约不适合 `workitem search-filter`：用 `workitem search-by-params`
3. 字段 key 用 `workitem meta-fields` 查，按 `field_name` 定位，取 `field_key`

```bash
# Step 1：如果目标类型支持基础名称匹配，用 search-filter 查目标 ID
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TARGET_TYPE_KEY"]' \
  --work-item-name "目标名称" \
  --format json | jq '[.data[] | {id, name}]'

# Step 1b：如果当前授权或接口契约不适合 search-filter，改用 search-by-params 查目标 ID
meegle workitem search-by-params \
  --project-key PROJ \
  --work-item-type-key TARGET_TYPE_KEY \
  --search-group '{"conjunction":"AND","search_params":[{"param_key":"people","operator":"HAS ANY OF","value":["USER_KEY"]}],"search_groups":[]}' \
  --format json | jq '[.data[] | {id, name}]'

# Step 2：查字段 key
meegle workitem meta-fields \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json | jq '[.data[] | select(.field_type_key=="workitem_related_select" or .field_type_key=="work_item_related_select") | {field_key, field_name, field_type_key}]'

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
