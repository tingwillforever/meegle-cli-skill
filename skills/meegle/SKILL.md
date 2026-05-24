---
name: meegle
description: |
  飞书项目（Meegle/Meego）私有部署 CLI 操作工具。Use this skill when the user needs to query spaces, views, work items, workflow state, comments, subtasks, release deploy tasks, or validate the private remote MCP runtime. 关键词：飞书项目、meegle、meego、工作项、需求、缺陷、任务、视图、节点、流转、发布任务、部署任务。
---

# 飞书项目 (Meegle) 私有 CLI 操作指南

本技能通过 Meegle CLI来操作飞书项目数据。输出语言跟随用户输入语言，默认中文。技能沿用 upstream Meegle CLI skill 的组织方式。核心主路径尽量保持 upstream-compatible，少量私有扩展会显式标注。命令和参数以 live CLI 为准。

默认运行模型：

1. 使用已安装的 `meegle` CLI。
2. 通过 remote MCP Server + SSO 登录访问私有部署。

`meegle doctor` 仅在以下情况使用：用户主动要求诊断，或业务命令报错且错误信息不足以定位根因。正常路径直接执行业务命令。

## URL 入口规则

用户提供 URL 时，**第一条命令必须是**：

```bash
meegle url decode --url '<URL>' --format json
```

禁止从路径段猜测任何参数，无论看起来多明显。

`url_kind == workitem_detail` 时，固定执行以下两条命令，参数直接来自 `url decode` 输出，**不得修改命令结构**：

```bash
# 命令 A：work_item_type 是 api_name，不是 UUID，必须先转换
meegle workitem meta-types --project-key <simple_name> --format json
# 从返回的 data[] 中找 api_name == <work_item_type> 的条目，取其 type_key 字段

# 命令 B：--work-item-ids 是复数，值是 JSON 数组字符串（含方括号和引号）
meegle workitem get --project-key <simple_name> --work-item-type-key <type_key从A> --work-item-ids '[<work_item_id>]' --format json
```

其他 url_kind 按 [references/url-kinds.md](references/url-kinds.md) 路由。

## 命令面权威

命令和参数以 live CLI 为准：

```bash
meegle inspect <resource>.<method> --format json
```

当文档与 CLI 实际行为不一致时，优先相信：

1. `meegle inspect ... --format json`
2. [references/verified-command-surface.md](references/verified-command-surface.md)
3. 本目录 reference 中的 `Private CLI 差异`

## CLI flag 语义层

先判断 flag 属于哪一层，再决定能否用于“过滤后端数据”：

| 语义层 | 典型 flag | 职责 |
|---|---|---|
| Request input | 命令自身 flags、`--params/-P`、`--set`、支持 backend projection 的 `--select` | 构造后端请求，影响查询条件、分页、字段 projection 或写入内容 |
| Execution control | `--dry-run`、`--refresh` | 控制 CLI 执行流程，不进入业务请求数据 |
| Output display | `--format`、`--envelope`、`--verbose`、`--output-select` | 控制返回后的本地展示，不改变后端查询语义 |
| Compat / lower-level | `--fields` 等 API-native 参数 | 直接暴露底层 API 能力，仅在命令特定兼容场景使用 |

Projection 规则：

- `--select` 的目标语义是后端字段 projection。当前默认只在 `workitem get`、`workitem search-by-params` 上作为 productized projection facade 使用，并映射为后端 `data.fields`。
- `--output-select` 是本地返回后裁剪，适合减少展示字段；它不减少后端返回数据量，也不改变过滤条件。
- `--fields` 是 API-native compatibility input。若命令同时可用 `--select` 与 `--fields`，默认优先 `--select`；不要在同一命令里组合二者。
- 未声明 backend projection 的命令上，`--select` 会直接失败；若目标只是展示裁剪，改用 `--output-select`，若目标是后端 projection，换用支持 projection 的命令。

Dry-run 规则：

- `--dry-run` 验证的是 normalized backend request construction。涉及 `--params/-P`、`--set`、时间范围、分页、projection 或高风险写入时，先 dry-run，确认 `.params` 中出现预期请求字段。
- 不要把 dry-run 输出当成本地最终渲染形状证明；`--format`、`--envelope`、`--verbose`、`--output-select` 属于输出展示层。

**查询职责边界**：

- `workitem search-filter`：常见场景的简化查询路径，适合名称模糊匹配和内置维度过滤（业务线、时间、状态、优先级、tag、user_keys）。
- `workitem search-by-params`：通用结构化查询路径，可用于任意工作项类型；凡是自定义字段、关联工作项字段、复杂 `search_group` 组合，都走这条路径。
- 当两者都可表达时，优先 `workitem search-filter`；当需要字段级条件，或当前授权/接口契约不适合 `search-filter` 时，改用 `workitem search-by-params`。
- 不要因为服务端内部可能把部分 `search-filter` 改写为 `search-by-params`，就把两者当成同一层能力；对外仍按上述职责选命令。

**当前用户相关工作项查询约束**：

- 当用户说“我参与的”“我的”“与我相关的”某类工作项时，不能直接查询该类型全量列表。
- 若使用 `workitem search-filter`，必须显式加 `--user-keys '["<meegle_user_key>"]'`。`--user-keys` 的语义是“与这些用户相关的工作项”，匹配 creator / follower / role owner。
- 不带 `--user-keys` 的查询，只能解释为“空间内该类型工作项列表”，不能默认解释为“当前用户相关列表”。
- 若用户要求更严格的字段级人员语义（如“我负责的”“people 字段包含我”），再改用 `workitem search-by-params` 的 `people` 条件或对应字段条件。

**查询结果展示规则**：

- 面向用户展示查询结果时，默认输出中文语义或可读 label，不直接输出 opaque key / id / state_key / option value。
- 若底层返回的是 key/value 形态，先补做映射再展示；原始 key 仅在排障、精确比对、或映射缺失时作为括号附注保留。
- 常见映射来源：状态用 `workitem meta-fields` 的 `options[].label`；业务线优先用 `auth whoami` 的 names 或 `space business-lines`；角色用 `workitem meta-roles`；人员用 `user query` / `team list-members`。
- `current_nodes` 这类本身已返回节点中文名的字段，直接展示名称，不要再退化成内部 key。

不要猜测：

- `project_key`
- `work_item_type_key`
- `node_id`
- 字段 key
- 枚举 option id
- URL 路径段中的任何参数（必须走 `url decode`）

**`project_key` 使用规则**：优先直接传用户提供的 `simple_name`（如 `cbg_product_develop`）。只有当命令或接口明确要求 UUID 形式时，才通过 `meegle space detail --simple-names '["<simple_name>"]'` 换取 UUID。`space list` 不返回 `simple_name`，不要用它来查找空间。

## 上下文推断

当命令需要业务线、所属项目或产品型号/子平台但用户未指定时，按以下顺序推断：

1. `meegle auth whoami --format json` 取 `business_line_keys/names`；若需要业务线 ID，用 `meegle space business-lines --project-key PROJ --format json` 按 `name` 匹配取 `id`
2. `workitem meta-types --project-key <project_key>` 找 `api_name == pdm` 的条目，取其 `type_key`；若只需要当前授权摘要，优先看 `meegle auth whoami --format json`。若需要项目明细，适用上面的“当前用户相关工作项查询约束”：当前用户参与/相关的项目，`workitem search-filter` 必须显式加 `--user-keys '["<meegle_user_key>"]'`；只有在要看空间内全量项目管理工作项时，才允许不带 `--user-keys`；若需要更严格的字段级人员语义或当前授权/接口契约不适合 `search-filter`，再改用 `workitem search-by-params`
3. 同上找 `api_name == product_type` 的 `type_key`；再用 `workitem search-filter --work-item-type-keys '[<type_key>]'` 取产品型号/子平台，结果按业务线客户端过滤

每步规则：
- 单个结果 → 直接使用，不询问
- 多个结果 → 编号列表呈现，等待用户选择；业务线多个时先选业务线，再用业务线 ID 过滤后续查询

推断结果缓存会话内，同一会话不重复询问。推断完成后询问是否保存到 Agent memory。

## 推荐执行顺序

0. **用户提供 URL 时**：`meegle url decode --url '<URL>' --format json`，按 url-kinds.md 路由
1. 确认空间和类型：直接用用户提供的 `simple_name` 作为 `project_key`；必要时用 `workitem meta-types` 确认类型
2. 读路径发现：`view search`、`view get`、`workitem search-filter`（基础查询）、`workitem search-by-params`（字段级查询）、`workitem get`、`workflow list-state-transitions`
   - `workitem get` / `workitem search-by-params` 只需后端字段 projection 时，用 `--select id,name,current_nodes,work_item_status,created_at`
   - `workitem search-filter` 这类列表响应，只需减少展示字段时用 `--output-select id,name,current_nodes,work_item_status,created_at`
   - `view items` 这类 object-wrapper 响应，只需减少展示字段时用 `--output-select data.name,data.view_id,data.work_item_id_list`
3. 写操作：`workitem create/update/remove/abort/restore/freeze/unfreeze`、`comment add/update/remove`、`subtask create/update/operate`
4. 临时或破坏性测试数据完成后清理

**并发规则**：无依赖的命令并行发起；有依赖必须串行（`space list` → `workitem meta-types` → `workitem meta-create-fields`；`workitem get` → `workitem update`）。分页查询先读首页取总数，按需翻页，只选必要字段。

## Reference Routing

只读取当前任务需要的 reference 文件。

| 场景 | Reference |
|---|---|
| 安装包 CLI 语法、inspect、输出格式 | [references/cli-guide.md](references/cli-guide.md) |
| 私有 remote MCP、SSO、授权前置检查、doctor 失败 | [references/runtime-private-remote-mcp.md](references/runtime-private-remote-mcp.md) |
| verified / conditional / unsupported 命令选择 | [references/verified-command-surface.md](references/verified-command-surface.md) |
| 可复制 CLI 示例 | [references/api-examples.md](references/api-examples.md) |
| 工作项类型、字段元数据 | [references/workitem.md](references/workitem.md) |
| 工作流查询、必填项、节点/状态流转辅助 | [references/workflow.md](references/workflow.md) |
| 创建工作项 SOP | [references/sop-create-workitem.md](references/sop-create-workitem.md) |
| 更新工作项 SOP | [references/sop-update-workitem.md](references/sop-update-workitem.md) |
| 节点流转 SOP | [references/sop-transition-node.md](references/sop-transition-node.md) |
| 状态流转 SOP | [references/sop-transition-state.md](references/sop-transition-state.md) |
| 发布/部署任务 SOP | [references/sop-deploy-task-release.md](references/sop-deploy-task-release.md) |
| URL 解析和 SOP 路由 | [references/url-kinds.md](references/url-kinds.md) |
| 视图查询 | [references/view.md](references/view.md) |
| 附件上传/下载 | [references/attachment.md](references/attachment.md) |
| 评论、团队成员、子任务等低频命令 | [references/misc.md](references/misc.md) |
| 错误自愈和熔断 | [references/error-handling.md](references/error-handling.md) |
| **字段值入参 / field_value shape / 写入 select / 富文本 / 关联字段等任何字段** | **[references/field-value-format.md](references/field-value-format.md)（构造任何 field_value 前必读）** |
| 关联工作项名称转 ID | [references/field-value-extras.md](references/field-value-extras.md) |
| **search-by-params 的 search_params 构造 / operator 枚举 / 固定 param_key / 关联字段 ID 查找** | **[references/search-params-format.md](references/search-params-format.md)（构造任何 search_params 前必读）** |
| ⚠️ MQL 语法背景（私有 CLI **当前不支持** MQL 命令，仅供了解语法背景；不可用于实际命令） | [references/mql-syntax.md](references/mql-syntax.md) |
| 富文本 Markdown 语法 | [references/rich-text-editor-markdown-syntax.md](references/rich-text-editor-markdown-syntax.md) |

## Upstream 差异总则

当前 public CLI 与 upstream 仍有少量差异，完整列表见 [references/verified-command-surface.md](references/verified-command-surface.md)。
