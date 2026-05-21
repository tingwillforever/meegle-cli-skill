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

不要猜测：

- `project_key`
- `work_item_type_key`
- `node_id`
- 字段 key
- 枚举 option id
- URL 路径段中的任何参数（必须走 `url decode`）

**`project_key` 使用规则**：优先直接传用户提供的 `simple_name`（如 `cbg_product_develop`）。只有当命令明确要求 UUID 形式（如 `view create-condition` / `view update-condition` 的 request body）时，才通过 `meegle space detail --simple-names '["<simple_name>"]'` 换取 UUID。`space list` 不返回 `simple_name`，不要用它来查找空间。

## 上下文推断

当命令需要业务线、所属项目或产品型号/子平台但用户未指定时，按以下顺序推断：

1. `meegle auth whoami --format json` 取 `business_line_keys/names`；若需要业务线 ID，用 `meegle space business-lines --project-key PROJ --format json` 按 `name` 匹配取 `id`
2. `workitem meta-types --project-key <project_key>` 找 `api_name == pdm` 的条目，取其 `type_key`；再用 `workitem search-filter --work-item-type-keys '[<type_key>]' --user-keys '[<meegle_user_key>]'` 取用户参与的项目
3. 同上找 `api_name == product_type` 的 `type_key`；再用 `workitem search-filter --work-item-type-keys '[<type_key>]'` 取产品型号/子平台，结果按业务线客户端过滤

每步规则：
- 单个结果 → 直接使用，不询问
- 多个结果 → 编号列表呈现，等待用户选择；业务线多个时先选业务线，再用业务线 ID 过滤后续查询

推断结果缓存会话内，同一会话不重复询问。推断完成后询问是否保存到 Agent memory。

## 推荐执行顺序

0. **用户提供 URL 时**：`meegle url decode --url '<URL>' --format json`，按 url-kinds.md 路由
1. 确认空间和类型：直接用用户提供的 `simple_name` 作为 `project_key`；必要时用 `workitem meta-types` 确认类型
2. 读路径发现：`view search`、`view get`、`workitem search-filter`、`workitem get`、`workflow list-state-transitions`
   - 只需摘要时加 `--select id,name,current_nodes,work_item_status,created_at` 投影，避免大响应体
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
