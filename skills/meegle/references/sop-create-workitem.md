# SOP: Create Work Item

> **CRITICAL** — 开始前先读 [`../SKILL.md`](../SKILL.md)（前置检查、授权流程、命令参数参考）和 [`error-handling.md`](error-handling.md)。

本 SOP 用于在飞书项目中创建工作项（需求、任务、缺陷等），全程自动化执行。

> 与上游 SaaS 版的关键差异（私有 cli）：
> - **角色（role）字段不可写**：私有 mcp 的 `workitem.create` 不暴露 `role_operate` 参数。如需设置角色成员，告知用户"私有部署 cli 暂不支持角色字段写入，请到 web 端操作"。
> - **按姓名查 userkey** 不可用：`user query` 只接受 `user_key` / `out_id` / `email`，不支持中文姓名搜索。
> - **模板 ID 是必填项**：创建时必须传 `--template-id`。

---

## 执行流程

### STEP 1 — 提取意图

从用户输入中提取：
- **空间名** — 哪个项目空间
- **工作项类型** — 需求 / 任务 / 缺陷 / 其他
- **字段值** — 标题、优先级、负责人、描述等
- **URL**（如有）— 先调 `meegle url decode --url '<URL>' --format json` 解析

### STEP 2 — 确认空间和类型

1. 用 `meegle space list --format json` 验证空间 → 获取 `project_key`
2. 用 `meegle workitem meta-types --project-key PROJ --format json` 获取类型列表 → 确认 `work_item_type_key`

> 唯一匹配则直接用，多个匹配则展示列表让用户选，无匹配则问用户。**禁止猜测。**

### STEP 3 — 收集元数据

```bash
meegle workitem meta-create-fields \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json
```

从返回中提取：
- **模板列表**：找 `field_key == "template"` 的字段，读 `options[]` 获取可用模板
- **候选字段**：遍历 `.data[]`，读取 `field_key` / `field_name` / `field_type_key` / `is_required` / `options[]`
- **字段配置**：用户提到的字段的 `field_key`、`field_type_key`、`options`

⚠️ 不要误读返回结构：`meta-create-fields` 的真实返回是 `.data[]` 扁平字段数组，不是 `.data.fields[]`。

⚠️ 不要跳过 `is_required`：这里的“必填”是**创建页必填约束**。`workitem create` 前必须为所有 `is_required == 1` 的字段准备非空值；如果某个必填字段在 create 阶段返回 `field [xxx] is illegal`，这是元数据与 create API 的契约不一致，不能删除该字段绕过创建。

### STEP 4 — 自动匹配模板

根据 STEP 3 获取的模板枚举值：
- **只有一个模板** → 自动选择
- **多个模板** → 根据用户描述中的关键词匹配最接近的模板名，选不出来时展示列表让用户选
- **用户明确指定了模板名** → 精确匹配

### STEP 5 — 构造创建 payload

优先采用 **完整必填策略**：

- 必传：`--name`，以及 `meta-create-fields` 中所有 `is_required == 1` 的字段
- `field_key == "name"` 用 `--name`
- `field_key == "template"` 优先用 `--template-id`
- 其他必填字段用 `--field-value-pairs`
- 可选字段仅在用户明确要求时追加

推荐优先级：

1. 标题、模板
2. 所有 `is_required == 1` 的字段
3. 用户明确要求的可选字段，例如 `description`
4. 未要求的可选字段不传

### STEP 6 — 转换字段值

🚨 **强制约束**：构造任何 `field_value` 前**必须先读** [field-value-format.md](field-value-format.md)，按 `field_type_key` 找到对应 shape 后再组装。**禁止**凭经验、记忆或别处 SOP 推断 shape；尤其禁止把数组/对象 `JSON.stringify` 再传（旧版 SOP 的 stringify 规则已废止）。不确定字段类型时先调 `meegle workitem meta-create-fields` 看 `field_type_key`。

**必填项缺失**时按下面顺序处理：
- 有用户输入 → 按字段类型转换后传入
- 没有用户输入但有合法默认值 → 仅在默认值来自元数据或业务约定明确时使用
- 人员类 / 关联类 / 业务域专用字段缺值 → 询问用户，不要创建空必填字段的工作项
- 必填字段在 `workitem create` 中触发 `field [xxx] is illegal` → **优先怀疑 shape 不匹配**，回去查 [field-value-format.md](field-value-format.md) 重组而非删字段绕过

**值转换速查**：

| 来源 | 转换 |
|------|------|
| 字段 shape（select / multi_user / schedule / 富文本 / 关联字段 等任何类型） | 一律查 [field-value-format.md](field-value-format.md) |
| 人名 | 让用户提供 email 或 user_key（私有 cli 不支持姓名搜索） |
| 枚举值 | 从 `meta-create-fields` 的 `options[].value` 取真实 option_id；**禁止照搬官方文档示例的 `"0"`/`"1"`** |
| 日期 | 转为毫秒时间戳 |
| 关联字段名称→ID | 用 `search-filter`/`search-by-params` 解析后传 number（见 [field-value-extras.md](field-value-extras.md)）|

### STEP 7 — 创建

```bash
meegle workitem create \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --name "标题" \
  --template-id 267706 \
  --field-value-pairs '[{"field_key":"priority","field_value":{"label":"P0","value":"option_1"}}]' \
  --format json
```

> `priority` 是 `select` 字段，必须传 `{label, value}` 对象，`value` 用 `meta-create-fields` 中 `options[].value` 的真实 option_id（不同租户不同）。其他 shape 见 [field-value-format.md](field-value-format.md)。

🚨 **批量创建**：当用户要求批量创建多个工作项时，必须**串行调用**（逐个请求），禁止高并发，以免触发平台限流。

### STEP 8 — 错误分流与降级

如果 `workitem create` 失败，按下面顺序处理：

- `field [xxx] is illegal`
  处理：先判断该字段是否 `is_required == 1`
  - 若是必填字段：停止，不要移除字段重试；说明这是创建页元数据与 create API 契约不一致
  - 若是可选字段：可移除该可选字段后重试一次，并在结果中说明该可选字段未写入
- 明确缺少模板
  处理：回到 STEP 3，读取 `field_key == "template"` 的 `options[]`
- 明确缺少某个字段
  处理：回到 STEP 3，核对所有 `is_required == 1` 字段并补齐

如果工作项已经创建成功：

- **不要**用删除必填字段的方式制造“创建成功”
- 若工作项是节点流（`pattern = Node`），改走 `workflow` 路径，在对应节点通过 `workflow transition --fields` / `workflow update-node` 补充
- 若字段明显不属于 workflow 可写范围，则告知用户改走 web 端

### STEP 9 — 确认结果

```bash
meegle workitem get \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-ids <新ID> \
  --format json
```

创建成功后，向用户展示：
- 工作项 ID 和名称
- 已设置的关键字段摘要

如果是临时验证项，只有在用户明确同意删除时才可用 `meegle workitem remove` 清理，并且必须先提示“删除后不可恢复”。

---

## 不可写入的字段类型

遇到时**直接跳过并告知用户**：

| 类型 | 原因 |
|------|------|
| `file` / `multi-file`（附件） | 创建后再用 `attachment upload` 追加附件；当前创建接口不直接内联上传文件 |
| `vote-boolean`（轻量表态） | 计数器，只能页面操作 |
| `vote-option` / `vote-option-multi`（投票） | 不支持接口写 |
| `compound_field` / `multi_user_compound_field`（复合明细表） | API 暂不支持 |
| 计算字段 | 系统自动算，只读 |

---

## 错误自愈

通用规则见 [`error-handling.md`](error-handling.md)。本 SOP 补充：

| 报错特征 | 自愈动作 |
|---------|---------|
| `need STRING type, but got: LIST/MAP` | shape 不匹配；回查 [field-value-format.md](field-value-format.md) 找正确 shape，**禁止** JSON.stringify 绕过 |
| `json: unsupported type` / 网络超时 | 原参数直接重试 |
| 字段 key 不匹配 | 用 `workitem meta-create-fields` 全量返回按 `field_name` 模糊匹配 |
| `invalid select option(s)` | 从 meta 的 `options[]` 匹配；唯一匹配则修正重试，否则展示候选让用户选 |
| `field [xxx] is illegal` | 若字段是 `meta-create-fields.is_required == 1`，停止并报告元数据/create 契约不一致；若是可选字段，移除该可选字段后最多重试一次 |
| `不满足层级配置` | 查 `children` 树，展示末级叶子节点让用户选择 |
| 明确缺少必填字段 | 核对字段类型限制，关联工作项尝试数字↔字符串切换 |

---

## 熔断条件

1. **工作项类型未找到** — `workitem meta-types` 失败超过 3 次
2. **字段转换大面积失败** — 转换失败比例 > 60%，终止流程并列出失败字段明细

---

## 常见问题

| 问题 | 处理 |
|------|------|
| 用户未指定空间 | 优先用 profile 默认 `project_key`，没有则问用户 |
| 用户未指定类型 | 如空间只有一种类型则直接用，否则问用户 |
| 用户提到的字段不存在 | `workitem meta-create-fields` 全量返回按 `field_name` 模糊匹配，找不到则告知用户 |
| 模板有多个 | 根据关键词匹配，匹配不到则展示列表让用户选 |
| 枚举值匹配不到 | 展示该字段所有枚举值让用户选 |
| 人名无法解析 | 告知用户提供 email 或 user_key |
