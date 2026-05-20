# 工作项元数据命令

查询工作项类型、字段、角色配置的辅助命令。在 `workitem create` / `workitem update` / `workitem get` 之前用来确认合法 key。

所有 workitem meta 命令已与 upstream 完全对齐：
- `workitem meta-types` — 列出空间下所有工作项类型
- `workitem meta-fields` — 列出字段配置（可按工作项类型过滤）
- `workitem meta-roles` — 列出流程角色配置
- `workitem meta-create-fields` — 获取创建工作项所需的元数据

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
