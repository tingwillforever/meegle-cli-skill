# Verified Command Surface

Use this file to choose the default-safe command path.

## Command Alignment Status

**⚠️ 核心主路径尽量与 upstream 对齐，但仍有少量差异**

当前 public CLI 优先暴露 upstream-compatible 主路径，并保留少量显式批准的私有扩展。以 `meegle inspect` 的 live 输出为准。

## Upstream Commands Support Status

| Upstream 命令 | 支持状态 | 说明 |
|--------------|---------|------|
| `space list` | ✅ 支持 | |
| `workitem create` | ✅ 支持 | |
| `workitem get` | ✅ 支持 | |
| `workitem update` | ✅ 支持 | |
| `workitem query` | ❌ 不支持 | 使用 `workitem search-by-params` / `workitem search-filter` 代替 |
| `workitem meta-types` | ✅ 支持 | |
| `workitem meta-fields` | ✅ 支持 | |
| `workitem meta-roles` | ✅ 支持 | |
| `workitem meta-create-fields` | ✅ 支持 | |
| `workflow transition` | ✅ 支持 | |
| `workflow transition-state` | ✅ 支持 | |
| `workflow update-node` | ✅ 支持 | |
| `workflow list-state-transitions` | ✅ 支持 | |
| `workflow list-state-required` | ✅ 支持 | |
| `workflow meta-node-fields` | ❌ 不支持 | MCP 无对应工具 |
| `user search` | ✅ 支持 | 姓名/关键字检索需带 `--project-key` |
| `team list-members` | ✅ 支持 | |
| `view list` | ✅ 支持 | |
| `view items` | ✅ 支持 | |
| `view create-fixed` | ✅ 支持 | |
| `view update-fixed` | ✅ 支持 | |
| `view delete` | ✅ 支持 | |
| `view create-condition` | ✅ 支持 | |
| `view update-condition` | ✅ 支持 | |
| `chart get` | ✅ 支持 | |
| `chart list` | ✅ 支持 | |
| `workhour list-records` | ✅ 支持 | |
| `workhour list-schedule` | ❌ 不支持 | MCP 无对应工具 |
| `attachment upload-file` | ✅ 支持 | 按 MCP 实际工具公开；适合富文本图片、通用文件上传 |
| `attachment upload` | ✅ 支持 | 按 MCP 实际工具公开；直接上传并挂到工作项附件字段 |
| `attachment download` | ✅ 支持 | |
| `attachment delete` | ✅ 支持 | destructive；仅在用户明确要求删除附件时使用 |
| `comment add` | ✅ 支持 | |
| `comment list` | ✅ 支持 | |
| `subtask update` | ✅ 支持 | |
| `mywork todo` | ❌ 不支持 | MCP 未提供 |

**覆盖率**: 34/37 = 91.9%

## Verified Commands

Prefer these by default:

### Project & Space
- `space list`
- `space detail`
- `space business-lines`
- `workitem meta-types`
- `team list-members`

### Work Item
- `workitem create`
- `workitem get`
- `workitem update`
- `workitem meta-create-fields`
- `workitem meta-fields`
- `workitem meta-roles`

### Workflow
- `workflow list-state-transitions`
- `workflow transition`
- `workflow transition-state`
- `workflow update-node`
- `workflow list-state-required`

### View
- `view list`
- `view items`
- `view create-fixed`
- `view update-fixed`
- `view delete`
- `view create-condition`
- `view update-condition`

### Chart
- `chart get`
- `chart list`

### Work Hour
- `workhour list-records`

### Attachment
- `attachment upload-file`
- `attachment upload`
- `attachment download`

### Comment
- `comment add`
- `comment list`
- `comment update`

### Subtask
- `subtask list`
- `subtask create`
- `subtask update`
- `subtask operate`

### User
- `user search`
- `user query`

### Private Extensions
- `workitem abort`
- `workitem restore`
- `workitem freeze`
- `workitem unfreeze`
- `workitem search-filter`
- `workitem search-by-params`
- `workitem list-op-records` — body 中 `project_key` 必须是 UUID（CLI 自动从 simple_name 转换，参考 `error-handling.md` Pitfall 10）；upstream spec 不接受 `work_item_type_key` 字段，但 CLI/MCP 仍要求该参数用于客户端授权范围判定，缺失会得到 `work_item_type_required`；额外可选过滤参数：`start_from`、`operator`、`operator_type`、`source_type`、`source`、`start`/`end`
- `user me`
- `release deploy-task-*`

## Conditional Commands

Allowed only after prerequisite discovery:

- `workflow list-state-required`
- `workflow transition-state`
- `workflow transition`
- `workflow update-node`
- `workitem abort`
- `workitem restore`
- `workitem freeze`
- `workitem unfreeze`
- `space detail`
- `attachment delete` destructive path: only after the user explicitly asks to delete attachments, and always warn that deletion is irreversible
- `comment remove` destructive path: only after the user explicitly asks to delete a comment, and always warn that deletion is irreversible
- `release deploy-task-create`
- `release deploy-task-execute`
- `release deploy-task-apply-white-list`
- `release deploy-task-verify`

Use `meegle inspect <resource>.<method>` first and check the caveat.

## Unsupported Commands

| 命令 | 原因 | 替代方案 |
|------|------|---------|
| `mywork todo` | MCP 未提供 | 使用 `workitem search-by-params` / `workitem search-filter` 组合查询 |

## Stable Default Flow

Read path:
- `space list` only when current scope is unknown or cross-space discovery is required
- `workitem meta-types` to list available work item types
- `workitem meta-create-fields` to get field metadata for creating work items
- `workitem meta-fields` to get detailed field configuration
- `workitem meta-roles` to get role configuration
- `workitem get` for reading work item details
- `workflow list-state-transitions` for workflow state inspection

Write path:
- `workitem create` for new work items
- `workitem update` for field updates
- `workflow transition` for node flow transitions
- `workflow transition-state` for state flow transitions
- `workflow update-node` for node metadata updates
