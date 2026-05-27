# 其它低频命令

## 与 upstream 差异

| upstream | 本地 CLI | 说明 |
|---|---|---|
| `team list` | 不支持 | MCP 无对应工具 |
| `team list-members` | `team list-members` | ✅ 已对齐 |
| `chart get` / `chart list` | `chart get` / `chart list` | ✅ 已对齐 |
| `relation list` / `relation meta-definitions` | 不支持 | relation 域与 upstream/MCP 语义不一致，当前 public CLI 暂不开放 |
| `workhour list-records` | `workhour list-records` | ✅ 已对齐 |
| `workhour list-schedule` | 不支持 | MCP 无对应工具 |
| `mywork todo` | 不支持 | MCP 未提供 |

本文件只收录低频但 live CLI 当前可用的路径。其它 upstream 低频命令统一按 [verified-command-surface.md](verified-command-surface.md) 处理。

---

## 空间团队

### team list-members

查看当前 `project-key` 下的团队列表及其成员。返回项包含 `team_id`、`team_name`、`user_keys`、`administrators`。该命令当前映射到 `space.teamMembers`，语义是“空间下团队成员”，不是空间成员全集；空间成员范围通常大于这些团队成员的并集。CLI 也不提供按 `team_id` 直查单个团队的入口，需要本地按返回结果过滤。适用于查看某个团队的成员/管理员，或在明确目标属于某个团队时做人工比对；不要用它断言“某人不在空间里”。

```bash
meegle team list-members \
  --project-key PROJ \
  --format json
```

## 子任务

子任务常用路径仍按主 SOP 的先读后写规则：先 `workflow list-state-transitions` 获取合法 `node_id`，再执行子任务命令。

创建子任务时，若用户**显式指定负责人**，按用户给出的标识设置 `--assignee`：

- 已知 `user_key`：直接传 `subtask create --assignee '["USER_KEY"]'`
- 已知 `email` / `out_id`：先用 `meegle user query` 做精确解析，再取 `user_key`
- 已知中文名/关键词：先用 `meegle user search --query "姓名" --project-key PROJ --format json` 解析到 `user_key`；若同名冲突，展示候选 `email` / `user_key` 让用户确认

若用户**未指定负责人**，默认省略 `--assignee`，保留节点/后端默认负责人逻辑；不要额外猜测用户，也不要把“未指定负责人”误改写成必须显式传某个 `user_key`。角色负责人改走 `--role-assignee`。

```bash
meegle subtask list \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --node-id NODE_ID \
  --format json
```

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

## 工作项生命周期

`workitem abort` / `restore` / `freeze` / `unfreeze` 已公开，但都属于 conditional lifecycle path。执行前必须先确认目标工作项 ID、目标状态变化，以及所需 reason / reason_option / boolean 控制参数。

## 评论

默认写评论用 `comment add`，更新已有评论用 `comment update`；查询评论用 `comment list`。删除评论仅在用户明确要求时才可用 `comment remove`，并且必须先提示“删除后不可恢复”。

```bash
meegle comment list \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --format json
```

```bash
meegle comment update \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --comment-id COMMENT_ID \
  --content "更新后的评论内容" \
  --format json
```
