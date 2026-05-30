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

`meegle doctor` 只在按需诊断场景使用：用户主动要求诊断、登录/配置异常、业务命令报错但难以定位，或 `inspect` / 执行结果显示命令面疑似漂移、`runtime_source != live`。不要把 `doctor` 当作业务命令固定前置；诊断细节见 [references/runtime-private-remote-mcp.md](references/runtime-private-remote-mcp.md)。

## URL 入口规则

用户提供 URL 时，**第一条命令必须是**：

```bash
meegle url decode --url '<URL>' --format json
```

禁止从路径段猜测任何参数，无论看起来多明显。

URL 解出的 `work_item_type` 永远先按 `api_name` 处理，不是可直接传给业务命令的 `work_item_type_key`。在 `workitem get`、`view list`、`workitem update`、`workflow.*` 等任何需要 `--work-item-type-key` 的命令之前，必须先执行 `meegle workitem meta-types --project-key <simple_name> --format json`，按 `api_name == <work_item_type>` 精确匹配取 `type_key`；禁止从 URL、浏览器页面、缓存、历史运行或猜测值直接填 `--work-item-type-key`。

`url_kind == workitem_detail` 时，固定执行以下两条命令，参数直接来自 `url decode` 输出，**不得修改命令结构**：

```bash
# 命令 A：work_item_type 是 api_name，不是 UUID，必须先转换
meegle workitem meta-types --project-key <simple_name> --format json
# 从返回的 data[] 中找 api_name == <work_item_type> 的条目，取其 type_key 字段

# 命令 B：--work-item-ids 是复数，值是 JSON 数组字符串（含方括号和引号）
meegle workitem get --project-key <simple_name> --work-item-type-key <type_key从A> --work-item-ids '[<work_item_id>]' --format json
```

其他 url_kind 按 [references/url-kinds.md](references/url-kinds.md) 路由；`chart_detail` / `view_chart`、条件视图、unsupported URL 等细节只在该文件维护，不在主文重复展开。

## 命令面权威

命令和参数以 live CLI 为准：

```bash
meegle inspect <resource>.<method> --format json
```

把 `inspect --format json` 视为 **manifest-backed public parameter descriptor**。构造命令时，优先看 `parameters[].flag`（CLI 直接可执行 flag）、projection metadata、`runtime_source` / `snapshot_stale`、`deprecation.*`；字段级解释见 [references/cli-guide.md](references/cli-guide.md)。

当文档与 CLI 实际行为不一致时，优先相信：

1. `meegle inspect ... --format json`
2. [references/verified-command-surface.md](references/verified-command-surface.md)
3. 本目录 reference 中的 `Private CLI 差异`

如果 `inspect` 显示：

- `runtime_source == "live"`：可按正常业务路径执行
- `runtime_source == "snapshot"`：只允许 `inspect` / `doctor` 等只读诊断；**不要执行业务写命令，也不要假设命令面仍然可执行**
- `deprecation.replacement` 存在：优先迁到 replacement，不再把旧命令当默认路径

涉及 `--select` 时，不要猜命令是否支持 backend projection。先看 `inspect --format json` 的 projection metadata，再决定用 `--select` 还是 `--output-select`。

## CLI 执行语义

把主文档当成决策入口，细节按 Reference Routing 下钻。URL / 视图类路由细则只在 [references/url-kinds.md](references/url-kinds.md) 维护；工作项快路径、当前用户相关语义、状态映射、一次 `meta-fields` + 一次最终查询等细则只在 [references/workitem.md](references/workitem.md) 维护；命令支持矩阵只在 [references/verified-command-surface.md](references/verified-command-surface.md) 维护。关键原则：

- 先判断 flag 语义层：request input 会进入后端请求；execution control 控制执行；output display 只影响本地展示；compat / lower-level 仅在命令特定兼容场景使用。
- `--select` 是后端字段 projection；只有 `inspect --format json` 声明 `projection.backend_select_supported == true` 时才用。
- `--output-select` 只裁剪本地展示，不减少后端返回、不改变过滤条件。
- 涉及写操作、复杂嵌套对象、时间范围或明确排障场景时，先用 `--dry-run` 确认 normalized request。普通只读快路径查询默认不要先加 `--dry-run`，避免把一次查询变成两次业务命令。
- destructive 命令（`comment remove`、`attachment delete`、`view delete`）必须带 `--confirm` 才能执行；conditional 命令会输出 stderr warning 但不阻断；`risk_tier` 通过 `inspect --format json` 查看。
- CLI 语义层、projection、dry-run、`--fields` 兼容边界的完整规则见 [references/cli-guide.md](references/cli-guide.md)。

## 查询主路径

**查询快速决策**：

- 用户给 URL：第一步只做 `meegle url decode --url '<URL>' --format json`，再按 `url_kind` 路由。
- `project_key` 就是空间 key。用户未显式指定空间时，优先使用当前登录 profile / `auth whoami` 暴露的默认 `project_key`；用户已给 `project_key` / `simple_name`（如 `cbg_product_develop`）时，直接把它用于 `--project-key`。不要为了“确认空间”每次都跑 `space list` / `space detail`。只有用户只给中文空间名、当前 profile 暴露多个空间且任务无法判定、或命令明确要求 UUID 时，才进入空间发现路径。
- 只按名称、时间、状态、优先级、tag、业务线、当前用户相关等内置维度查列表：优先 `workitem search-filter`。
- 涉及自定义字段、关联字段、复杂 AND/OR、字段级人员语义或 `search-filter` 无法表达的条件：使用 `workitem search-by-params`。
- 需要确认工作项类型：先 `workitem meta-types --project-key <project_key> --format json`，按“显式指定优先精确匹配、模糊描述只在启用候选里做唯一解析”的规则找 `type_key`。显式指定（`type_key`、精确 `api_name`、精确 `name`）只做精确命中；模糊描述（如“缺陷”“需求”“迭代”）先过滤停用类型（`is_disable != 1`），只有唯一候选时才自动绑定，不唯一就追问。禁止用 `.[0]`、首条近似项或通用 `api_name` 抢答。
- 所有 `--work-item-type-key` / `--work-item-type-keys` 入参都必须使用 `meta-types` 返回的 UUID `type_key`；不要把 `story`、`story_new`、`issue`、`task`、`pdm`、`iteration` 等 api_name 当作 type key 试探查询。
- 需要确认字段 key、状态 value、枚举 option value：先 `workitem meta-fields --project-key <project_key> --work-item-type-key <type_key> --format json`。
- `workitem meta-fields` 是查询、过滤、展示映射的字段元数据命令；`workitem meta-create-fields` 只用于创建页/创建必填字段，不要用它替代查询字段元数据。
- 不确定命令参数、projection 或 dry-run 能力：先 `meegle inspect <resource>.<method> --format json`。
- 工作项查询、当前用户相关语义、状态映射、只读快路径收敛规则统一看 [references/workitem.md](references/workitem.md)；主文不重复维护 case 级细则。
- 图表 URL / `chart get` 场景遵循“一次 live 读取，后续只做本地整理”的快路径：`url decode -> chart get` 成功一次后，必须基于该次返回在本地提取标题、维度、指标、排行或摘要；不要为了不同排序口径、`jq` 格式化或字段裁剪重复执行第二次 `chart get`。
- 工作项列表只读快路径也遵循同样的“单次 live 读取”原则：如果第一次结果已经满足默认展示页大小，就直接回答；不要因为 `pagination.total` 大于当前页大小，就擅自把 `page-size 10` 扩成 `50` 或重跑同条件查询。要展示更多结果，必须等用户明确追问“继续/全部列出/导出”。

**复杂查询主体优先策略**：

复杂查询先明确最终要返回的对象类型，再查筛选锚点和字段元数据。用户先提到的对象不一定是查询主体；在“查询 A 的 B / A 下的 B / 关联到 A 的 B”里，通常 `B` 是查询主体，`A` 是筛选锚点。

执行复杂查询前，先在内部明确这四项判断；只有查询歧义较大或需要用户确认时，才展示给用户：

```text
查询主体：
筛选锚点：
过滤条件：
展示字段：
```

- 如果查询主体是工作项，主体决定 `work-item-type-key`，也决定应该读取哪个类型的 `meta-fields`。
- 如果查询主体是视图、评论、子任务、流程状态或发布/部署任务，先走对应 reference 和 `inspect`，不要套用工作项元数据路径。
- 筛选锚点用于缩小范围；如果锚点是工作项，先定位锚点 ID，再在查询主体类型或对应 reference 中找限制范围的字段/参数。
- 状态、负责人、版本、迭代、业务线、时间范围通常是过滤条件，不要误判成查询主体。
- 工作项主体的字段 key、状态 value、枚举 option value 从该工作项类型的 `meta-fields` 获取；非工作项主体按对应 reference 和 `inspect` 确认参数。
- `work_item_status` 中文展示优先从 `meta-fields` 的 `work_item_status.options[]` 做 `value → label` 映射；不要为了展示状态中文名绕到 `workflow list-state-transitions`。但在列表结果已包含 `current_nodes[].name` 时，默认直接把节点名作为“状态/当前阶段”展示，不要再额外补状态映射提取。
- 只读展示任务如果已经拿到查询结果，不要为了“整理输出”再次执行相同查询；应在同一份结果上本地映射状态 label、裁剪字段并直接回答。
- 只有完成主体判断后，再选择 `search-filter`、`search-by-params`、`workitem get` 或 `view items`。
- 示例：“查询某项目下待讨论缺陷”应拆成 `查询主体=缺陷`、`筛选锚点=项目`、`过滤条件=状态待讨论`，再在缺陷类型中查“所属项目”字段和“待讨论”状态 value。
- 如果同一任务已经成功拿到足以回答的问题主体数据，就立即停止新增业务命令。回答阶段允许本地映射、裁剪、排序和格式化；不允许为了补标题、补状态映射、补排行或改输出样式而再打一轮相同业务命令。

**查询职责边界**：

- `workitem search-filter`：常见场景的简化查询路径，适合名称模糊匹配和内置维度过滤（业务线、时间、状态、优先级、tag、user_keys）。
- `workitem search-by-params`：通用结构化查询路径，可用于任意工作项类型；凡是自定义字段、可搜索的关联字段（以 live `field_type_key` 为准）、复杂 `search_group` 组合，都走这条路径。
- 当两者都可表达时，优先 `workitem search-filter`；当需要字段级条件，或当前授权/接口契约不适合 `search-filter` 时，改用 `workitem search-by-params`。
- 不要因为服务端内部可能把部分 `search-filter` 改写为 `search-by-params`，就把两者当成同一层能力；对外仍按上述职责选命令。

**工作项查询前检查单**：

- `project_key`：用户显式给出 `simple_name` 就直接传；未给出时优先当前登录 profile / `auth whoami` 的默认 `project_key`。
- `work_item_type_key`：来自 `workitem meta-types`，不要把 `api_name` 当 UUID type key 传给需要 type key 的命令。
- `work_item_type_keys`：同样来自 `workitem meta-types` 的 UUID `type_key` 数组；不允许用 api_name 数组先试探。
- 字段 key：来自 `workitem meta-fields`，自定义字段和关联字段都不要按中文字段名猜。
- 状态 / 枚举 value：来自 `meta-fields` 的 `options[].value`；展示时再映射回中文 label。
- 关联字段 value：使用被关联工作项的数字 ID，不使用名称、URL 片段或字符串 ID。
- 当前用户相关查询、展示映射、关联字段过滤细节见 [references/workitem.md](references/workitem.md) 和 [references/search-params-format.md](references/search-params-format.md)。

**关联字段查询限制**：

- `search-by-params` 支持通过 `workitem_related_select` / `work_item_related_select` 和 `workitem_related_multi_select` / `work_item_related_multi_select` 类型字段进行正向查询（以 live `field_type_key` 为准，查询字段值包含指定工作项 ID 的工作项）
- **不支持** `work_item_related` 类型字段的搜索
- 反向关联查询优先从父工作项读取关联字段再批量查询；若目标类型有指向父工作项的可搜索关联字段，可用 `search-by-params` 直接查。

当前用户相关语义、负责人字段过滤、列表展示裁剪、一次 `meta-fields` / 一次最终查询等规则统一以 [references/workitem.md](references/workitem.md) 为准。

不要猜测：

- `project_key`
- `work_item_type_key`
- `node_id`
- 字段 key
- 枚举 option id
- URL 路径段中的任何参数（必须走 `url decode`）

## 上下文推断

当命令需要业务线、所属项目或产品型号/子平台但用户未指定时，按以下顺序推断：

1. `meegle auth whoami --format json` 取 `business_line_keys/names`；若需要业务线 ID，用 `meegle space business-lines --project-key PROJ --format json` 按 `name` 匹配取 `id`
2. `workitem meta-types --project-key <project_key>` 找 `api_name == pdm` 的条目，取其 `type_key`；若只需要当前授权摘要，优先看 `meegle auth whoami --format json`。若需要项目明细，适用上面的“当前用户相关工作项查询约束”：当前用户参与/相关的项目，`workitem search-filter` 必须显式加 `--user-keys '["<meegle_user_key>"]'`；只有在要看空间内全量项目管理工作项时，才允许不带 `--user-keys`；若需要更严格的字段级人员语义或当前授权/接口契约不适合 `search-filter`，再改用 `workitem search-by-params`
3. 同上找 `api_name == product_type` 的 `type_key`；再用 `workitem search-filter --work-item-type-keys '[<type_key>]'` 取产品型号/子平台，结果按业务线客户端过滤

每步规则：
- 单个结果 → 直接使用，不询问
- 多个结果 → 编号列表呈现，等待用户选择；业务线多个时先选业务线，再用业务线 ID 过滤后续查询

推断结果仅在本轮会话内缓存，同一会话不重复询问。只有用户明确要求保存偏好，或当前环境明确提供可用 memory 工具时，才考虑持久化，避免无谓打断。

## 推荐执行顺序

0. **用户提供 URL 时**：`meegle url decode --url '<URL>' --format json`，按 url-kinds.md 路由
1. 复杂查询先执行“查询主体 / 筛选锚点 / 过滤条件 / 展示字段”判断
2. 确认空间、主体类型和锚点：工作项主体用 `workitem meta-types` / `meta-fields`；非工作项主体按 Reference Routing 进入对应 reference，并用 `inspect` 确认参数
3. 读路径发现：`view list`、`view items`、`workitem search-filter`、`workitem search-by-params`、`workitem get`、`workflow list-state-transitions`
4. 写操作：`workitem create/update/remove/abort/restore/freeze/unfreeze`、`comment add/update/remove`、`subtask create/update/operate`
5. 临时或破坏性测试数据完成后清理

**并发规则**：无依赖的命令并行发起；有依赖必须串行。分页查询先读首页取总数，按需翻页，只选必要字段。

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
| 评论、空间团队、子任务等低频命令 | [references/misc.md](references/misc.md) |
| 错误自愈和熔断 | [references/error-handling.md](references/error-handling.md) |
| **字段值入参 / field_value shape / 写入 select / 富文本 / 关联字段等任何字段** | **[references/field-value-format.md](references/field-value-format.md)（构造任何 field_value 前必读）** |
| 关联工作项名称转 ID | [references/field-value-extras.md](references/field-value-extras.md) |
| **search-by-params 的 search_params 构造 / operator 枚举 / 固定 param_key / 关联字段 ID 查找** | **[references/search-params-format.md](references/search-params-format.md)（构造任何 search_params 前必读）** |
| ⚠️ MQL 语法背景（私有 CLI **当前不支持** MQL 命令，仅供了解语法背景；不可用于实际命令） | [references/mql-syntax.md](references/mql-syntax.md) |
| 富文本 Markdown 语法 | [references/rich-text-editor-markdown-syntax.md](references/rich-text-editor-markdown-syntax.md) |

## Upstream 差异总则

当前 public CLI 与 upstream 仍有少量差异，完整列表见 [references/verified-command-surface.md](references/verified-command-surface.md)。
