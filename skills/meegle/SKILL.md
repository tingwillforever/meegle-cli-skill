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
3. 业务命令前先运行 `meegle doctor --format json`。

如果 `doctor` 失败，先处理运行时、认证或配置问题，不要继续业务命令。

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

## 推荐执行顺序

1. 运行时预检：`meegle doctor --format json`
2. 确认空间和类型：优先使用 profile 默认 `project_key`；必要时用 `space list` / `workitem meta-types`
3. 读路径发现：`view search`、`view get`、`workitem search-filter`、`workitem get`、`workflow list-state-transitions`
4. 写操作：`workitem create/update/remove/abort/restore/freeze/unfreeze`、`comment add/update/remove`、`subtask create/update/operate`
5. 临时或破坏性测试数据完成后清理

## Reference Routing

只读取当前任务需要的 reference 文件。

| 场景 | Reference |
|---|---|
| 安装包 CLI 语法、inspect、输出格式 | [references/cli-guide.md](references/cli-guide.md) |
| 私有 remote MCP、SSO、doctor 失败 | [references/runtime-private-remote-mcp.md](references/runtime-private-remote-mcp.md) |
| 授权前置检查 | [references/auth-guard.md](references/auth-guard.md) |
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
| MQL 语法背景（仅当 live CLI 支持对应搜索语义时使用） | [references/mql-syntax.md](references/mql-syntax.md) |
| 富文本 Markdown 语法 | [references/rich-text-editor-markdown-syntax.md](references/rich-text-editor-markdown-syntax.md) |
| 性能与并发调用 | [references/performance.md](references/performance.md) |

## Upstream 差异总则

当前 public CLI 与 upstream 仍有少量差异。明确不支持的命令有：

- `workflow meta-node-fields` — MCP 无对应工具，用 `workflow list-state-transitions` 返回的 `workflow_nodes[].fields` 替代
- `workhour list-schedule` — MCP 无对应工具
- `mywork todo` — MCP 未提供
