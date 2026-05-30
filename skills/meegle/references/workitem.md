# 工作项元数据命令

查询工作项类型、字段、角色配置的辅助命令。在 `workitem create` / `workitem update` / `workitem get` 之前用来确认合法 key。

所有 workitem meta 命令已与 upstream 完全对齐：
- `workitem meta-types` — 列出空间下所有工作项类型
- `workitem meta-fields` — 列出字段配置（可按工作项类型过滤）
- `workitem meta-roles` — 列出流程角色配置
- `workitem meta-create-fields` — 获取创建工作项所需的元数据

查询/过滤/展示映射默认使用 `workitem meta-fields`。`workitem meta-create-fields` 是创建页元数据，只在创建工作项、创建必填字段、创建字段 shape 或创建 API 报错自愈时使用；不要用它代替查询字段配置。

`project_key` 即空间 key。用户未指定空间时，优先使用当前登录 profile / `auth whoami` 暴露的默认空间 key；已知空间 key（例如 `cbg_product_develop`）时，直接作为 `--project-key` 使用。不要为了确认空间而先跑 `space list` / `space detail`；这类空间发现只适用于用户只给中文空间名、当前 profile 暴露多个空间且任务无法判定，或命令明确要求 UUID 的场景。

所有需要 `--work-item-type-key` / `--work-item-type-keys` 的命令都必须传 `workitem meta-types` 返回的 UUID `type_key`。不要用 `story`、`story_new`、`issue`、`task`、`pdm`、`iteration` 等 api_name 作为试探值；这些名称只能用于从 `meta-types` 结果里匹配真实 type_key。

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

### 快路径：状态中文名映射

查询结果里的 `work_item_status.state_key` 不是最终展示文案。需要中文状态名时，读取同一工作项类型的字段元数据一次：

```bash
meegle workitem meta-fields \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json
```

从 `field_key == "work_item_status"` 的 `options[]` 建立 `value → label` 映射，然后把查询结果里的 `state_key` / `value` 回填为 `label`。不要为了展示状态中文名调用 `workflow list-state-transitions`；workflow 命令服务于状态流转，不是列表展示 label 的默认路径。

但在普通列表查询里，如果结果已经包含 `current_nodes[].name`，默认直接用节点名作为“状态/当前阶段”展示。对大多数“标题、状态、负责人”类任务，这已经足够且更省命令；不要为了把节点名再映射成 `work_item_status` label，额外补一轮字段元数据提取。

同一类型的一次展示任务里，`meta-fields` 默认只读一次。读取完整字段元数据后，应在本地同时提取：

- `work_item_status.options[]` 的 `value → label`
- 负责人 / 关联字段的 `field_key`
- 枚举字段需要的 `options[].value`

不要为了单独拿 `work_item_status.options` 或单独确认负责人字段，再执行第二次 `meta-fields`。

### 快路径：待讨论缺陷 + 中文状态名 + 原始负责人 user_key

当任务是“查缺陷管理里待讨论缺陷，展示标题、状态、负责人，负责人只需要 raw user_key”时，最小推荐路径就是：

```bash
meegle workitem meta-types --project-key PROJ --format json
meegle workitem meta-fields --project-key PROJ --work-item-type-key BUG_TYPE_KEY --format json
meegle workitem search-by-params \
  --project-key PROJ \
  --work-item-type-key BUG_TYPE_KEY \
  --search-group '{"conjunction":"AND","search_params":[{"param_key":"work_item_status","operator":"HAS ANY OF","value":["STATUS_VALUE"]}],"search_groups":[]}' \
  --fields '["current_status_operator"]' \
  --page-size 10 \
  --format json
```

规则：

- `BUG_TYPE_KEY` 来自 `meta-types`
- `STATUS_VALUE` 来自同一次 `meta-fields` 返回里 `work_item_status.options[]`
- 负责人优先直接读最终查询结果中的 `current_status_operator`
- 默认只展示前 `10` 条
- 不要再执行第二次 `meta-fields | jq ...`
- 不要先裸跑一次 `search-by-params`，再同条件重跑第二次只为格式化输出

### 用户可读展示

对用户展示工作项查询结果时，默认做语义化回填，不直接输出原始 key：

- `work_item_status.state_key`：用 `workitem meta-fields` 中 `work_item_status.options[]` 建立 `value → label` 映射，默认显示中文状态名；只有排障时才附带原始 `state_key`
- `current_nodes[]`：直接显示节点 `name`
- `select` / `multi-select` / `tree-select` 等枚举字段：优先显示 `label`，不要把 `value` 直接展示给用户
- `business` / 业务线 ID：用 `meegle auth whoami --format json` 的 `business_line_names` 或 `meegle space business-lines` 返回名称回填
- 角色 key：用 `meegle workitem meta-roles --project-key PROJ --work-item-type-key TYPE_KEY --format json` 回填角色名称
- 人员 user_key：已知 `user_key` / `email` / `out_id` 需要精确解析时，可用 `meegle user query --format json` 回填精确对象；默认的人名/关键词解析仍优先 `meegle user search --query "姓名" --project-key PROJ --format json`。`user query` 的公开定位以 [verified-command-surface.md](verified-command-surface.md) 为准；若上下文明确是“空间下团队成员”，再用 `meegle team list-members --project-key PROJ --format json` 查看团队列表及其 `user_keys` / `administrators`，但不要把它当成空间成员全集

如果一时拿不到映射，先明确标注“原始 key”，不要把它误写成中文语义。

普通列表展示默认只取小页结果（10-20 条）并直接输出，不要为了“标题、状态、负责人”分页拉全量、导出文件或批量解析所有负责人。只有用户明确要求完整导出/全量统计时，才分页和写临时文件。

如果第一次最终查询已经返回了默认展示页且带有 `pagination.total`，正确回答方式是：

- 直接展示当前页结果
- 明确说明“共命中 N 条，当前先展示前 10 条”
- 若用户需要，再继续列更多结果

不要因为看到了 `pagination.total=32`，就立刻把同条件查询重跑成更大 `page-size`，也不要“再跑一遍只是为了本地裁成三列”。

不要在普通列表展示中使用 `user query | jq` 作为负责人批量回填路径。默认直接展示字段中已有 label/name；如果只有 user_key，就展示 user_key 并说明“负责人为原始 user_key，未做姓名回填”。只有用户明确要求解析人员姓名时，才小批量调用 user 查询。

---

## 当前用户相关查询

当用户说“我的”“我参与的”“与我相关的”某类工作项时，不能直接查询该类型全量列表。

- 若使用 `workitem search-filter`，必须显式加 `--user-keys '["<meegle_user_key>"]'`。`--user-keys` 匹配 creator / follower / role owner，语义是“与这些用户相关的工作项”。
- 不带 `--user-keys` 的查询，只能解释为“空间内该类型工作项列表”，不能默认解释为“当前用户相关列表”。
- 若用户要求更严格的字段级人员语义，如“我负责的”“people 字段包含我”，改用 `workitem search-by-params` 的 `people` 条件或对应字段条件。
- 当前登录用户的 `meegle_user_key` 优先来自 `meegle auth whoami --format json`；不要用 `user query --user-keys '["current_login_user()"]'` 替代字段级过滤身份发现。

### 快路径：我负责的 + 字段级人员过滤

“我负责的”“当前负责人是我”不是宽泛的“与我相关”。推荐路径：

```bash
meegle auth whoami --format json
meegle workitem meta-types --project-key PROJ --format json
meegle workitem meta-fields --project-key PROJ --work-item-type-key TYPE_KEY --format json
meegle workitem search-by-params \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --search-group '{"conjunction":"AND","search_params":[{"param_key":"OWNER_FIELD_KEY","operator":"HAS ANY OF","value":["USER_KEY"]}],"search_groups":[]}' \
  --format json
```

其中 `OWNER_FIELD_KEY` 和优先级枚举 value 来自 `meta-fields`。这个快路径默认直接用最终查询结果里的 `current_nodes[].name` 展示状态；不要为了状态展示再去抽 `work_item_status.options[]`。不要先试 `search-filter --user-keys` 再自愈；它覆盖 creator / follower / role owner，不能表达严格负责人字段语义。

这是只读快路径场景：默认直接执行真实查询，不要先对同一条 `search-by-params` 做 `--dry-run` 再执行一次真实请求；除非当前任务明确是排障或命令 shape 不确定。

同一 case 中不要先跑一个 `page-size 1` / sample probe 查询，再跑第二个正式分页查询。负责人字段、状态字段和优先级条件都应该在一次最终查询中完成；本地需要的表格格式化，直接接在这次最终查询输出后处理。

对 “我负责的高优先级产品需求，只要标题、状态和负责人” 这类快路径，推荐的最小序列固定为：

1. `meegle auth whoami --format json`
2. `meegle workitem meta-types --project-key PROJ --format json`
3. `meegle workitem meta-fields --project-key PROJ --work-item-type-key TYPE_KEY --format json`
4. `meegle workitem search-by-params --project-key PROJ --work-item-type-key TYPE_KEY --search-group ... --fields '["OWNER_FIELD_KEY","priority"]' --page-size 10 --format json`

规则补充：

- 第 3 步的同一份 `meta-fields` 至少提取负责人字段 key、优先级 option value；只有当前查询结果无法直接用 `current_nodes[].name` 展示状态时，才额外从同一份结果里取状态 `value → label` 映射
- 第 4 步直接作为最终查询；不要先跑 `page-size 20` 再缩成 `page-size 10`
- 不要再执行第二次 `search-by-params | jq ...` 只为输出 Markdown 表格
- 若需要展示总数，直接使用最终查询返回里的 `pagination.total`
- 回答阶段禁止再发第二次 `meta-fields` 去单独抽 `work_item_status.options`，也禁止为补标题/状态/负责人再发第二次同条件 `search-by-params`；标题、状态、负责人都必须从第 3 步和第 4 步这两份结果本地整理出来。
- 如果需要对第 3 步或第 4 步结果做多次本地提取，先把那一次真实返回保存到临时文件，再对文件执行本地 `jq`；不要为了“本地格式化更方便”重跑相同业务命令。

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

如果锚点类型已经由 `meta-types` 唯一确认（例如这里就是“迭代管理”），锚点 ID 查询必须直接限定在该 `type_key` 上。不要把全量 `type_key` 数组塞进 `search-filter` 做跨类型探测，也不要先用占位 type key 试探。

最终回复里如果说明关联字段查询，请明确写出：关联字段过滤的 `value` 使用被关联工作项的数字 ID，不使用标题字符串。

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

这同样是只读快路径：默认直接执行最终 `search-by-params`，不要先跑一遍 `--dry-run`；如果已经唯一确认了锚点 ID 和关联字段 key，再做 dry-run 只会增加业务命令数和 wall-clock。

如果锚点类型与字段 key 都已确定，推荐最终序列就是 4 步：

1. `meta-types`
2. 锚点 `search-filter`（限定锚点 type key）
3. 主体 `meta-fields`
4. 最终 `search-by-params`

不要在这四步之外加入 probe query、全类型探测或额外格式检查。

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

类型解析规则：

- 显式指定优先精确匹配：`type_key`、精确 `api_name`、精确 `name` 只做精确命中，不做模糊扩展
- 模糊描述只在启用候选里解析：默认先过滤停用类型（`is_disable != 1`）
- 模糊描述只有唯一候选时才自动绑定；0 个候选时说明无法判定；多个候选时追问用户
- 禁止用 `.[0]`、首条近似项或通用 `api_name` 作为默认兜底
- 创建、列表、查询等面向“当前可操作类型”的任务默认按上述启用候选解析；URL 详情、历史对象读取等已知对象读取场景，若上下文已经唯一给出类型，可按该对象真实类型继续，不因停用状态而强行改绑到别的类型

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
