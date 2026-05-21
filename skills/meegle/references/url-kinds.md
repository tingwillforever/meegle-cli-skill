# URL Kinds —— `url decode` 返回值到 SOP 的映射

## 为什么 skill 不自己拆 URL

Meegle / 飞书项目的路由非常多，且 snake_case 旧路径、`/meego/` 前缀、`_xxx_resource` 资源工作项、预置功能区（user-gantt / chart / multi-project-view 等）这些都会让"看起来像工作项详情页"的 URL 其实不是。**禁止**自己从 URL 截取路径段作参数。

统一走一条命令：

```bash
meegle url decode --url '<URL>' --format json
```

拿到 `url_kind` 后按本文表格选择 SOP 或回绝。纯本地解析，无网络调用。

---

## 返回字段

| 字段 | 说明 |
|---|---|
| `url_kind` | 必返；未识别时为 `unknown` |
| `simple_name` | 空间标识，即 `project_key`，可直接用于所有需要 `project_key` 的命令 |
| `work_item_type` | 工作项类型 `api_name`（已脱去 `_xxx_resource` 包装），**不是** `work_item_type_key`；后续必须再用 `meegle workitem meta-types --project-key <project_key>` 映射成 UUID 形态的真实 type key |
| `work_item_id` | 工作项 ID（字符串） |
| `view_id` / `chart_id` / `plugin_key` / `team_id` / `template_id` | 按路径分别返回 |
| `setting_type` | 设置页子参数（如 permission 类型） |
| `edit_str` | `homepage/edit`、`overview/edit` 的编辑态标记 |
| `is_resource` | true 表示路径里带 `_xxx_resource` 包装 |
| `query` | 原始 query 参数，保留 `scope/node` 等二级导航上下文 |
| `redirected_from` | 若经别名归一化或 `/meego/` 前缀剥离，记录原始路径 |
| `pathname` / `host` / `raw` | 诊断用 |

---

## `url_kind` → 允许的 SOP

### 工作项类

| url_kind | 可用字段 | 推荐 SOP / 命令 |
|---|---|---|
| `workitem_detail` | simple_name · work_item_type · work_item_id | 见下方三步完整示例（**禁止跳过 meta-types 直接用 api_name 当 type_key**） |
| `workitem_create` | simple_name · work_item_type | `sop-create-workitem`（`meegle workitem create`） |
| `workitem_draft` | simple_name · work_item_type | 同上，提示用户这是草稿视图 |
| `workitem_homepage` / `workitem_homepage_edit` | simple_name · work_item_type | 无具体工作项 ID — **拒绝**直接操作，要求用户提供详情页 URL 或工作项 ID |

### workitem_detail 三步完整示例

```bash
# 步骤 1：获取 type_key（work_item_type 是 api_name，不是 UUID，不能直接用）
meegle workitem meta-types --project-key <simple_name> --format json
# → 从 data[] 中找 api_name == work_item_type 的那条，取其 type_key

# 步骤 2：获取工作项（注意：--work-item-ids 是复数，值为 JSON 数组字符串）
meegle workitem get \
  --project-key <simple_name> \
  --work-item-type-key <type_key> \
  --work-item-ids '[<work_item_id>]' \
  --format json
```

**常见错误：**
- `--work-item-id`（单数）→ 不存在，必须用 `--work-item-ids`
- `--work-item-ids 20426988`（裸数字）→ 必须用 `'[20426988]'`（JSON 数组字符串）
- `--work-item-type-key story_new`（api_name）→ 必须先 meta-types 拿 UUID
### 视图类（有 `view_id` 但无 `work_item_id`）

| url_kind | 语义 | 处理 |
|---|---|---|
| `view_story` / `view_issue` | 需求 / 缺陷视图 | 如果用户想操作"这个视图里的工作项"，要求具体工作项 URL；否则用 `meegle view list` 确认视图，再用当前 public CLI 暴露的 `meegle view items` 读取 |
| `view_multi_project` / `view_project_overview` / `view_user_gantt` | 跨空间/全域/甘特视图 | 同上 |
| `view_chart` | 图表视图 | 当前 cli 不支持 chart 操作 — **拒绝** |
| `view_workitem` | 通用工作项视图 | 若 `is_resource=true`，`work_item_type` 已脱包装可直接用 |

### 图表类

当前 cli 不暴露 chart 操作。所有 `chart_*` 一律**拒绝**并告知用户用 web 端。

### 空间/设置类（写操作请走 OpenAPI，非本 skill 范围）

| url_kind | 说明 |
|---|---|
| `project_home` · `project_overview` · `project_empty` · `project_ai_assist` | 空间级落地页，`simple_name` 可用于 `meegle space list` 取 `project_key` |
| `project_overview_edit` | 编辑态，不作为操作目标 |
| `project_404` · `project_401` · `project_500` | 错误页，**拒绝** |
| `setting_*` | 各类设置页；本 skill 不做设置写操作，**拒绝**并告知 |
| `setting_other` | 未枚举的 setting 子页（前端通过非 exact 路由内部渲染），等同于 `setting_*` — **拒绝** |
| `import_jira` · `import_excel` · `data_recycle` | 导入/回收操作在界面内完成，**拒绝** |
| `plugin_page` | 插件页 — 行为由插件定义，CLI 无法操作，**拒绝** |

### 全局/导航类

| url_kind | 处理 |
|---|---|
| `workbench` · `workspaces` · `favorites` · `inbox` | 顶级导航页，**没有具体目标**，请追问 |
| `teams` · `team_detail` | 团队页；`team_detail` 的 `team_id` 可 `meegle team list-members --project-key PROJ` 获取项目成员（cli 没有按 team_id 直查的接口） |
| `templates` · `template_detail` · `template_manage` | 模板中心，本 skill 不做模板操作，**拒绝** |
| `project_list` | 全部空间列表，追问具体空间 |

### 系统域 `/b/*`

| url_kind | 处理 |
|---|---|
| `preference` · `mcp_config` · `mcp_auth` · `ai_hub` · `handover` · `onboarding_*` · `trial_*` · `cross_*` · `slack_connect` · `resource_handover` · `no_project_auth` · `login_datacenter` · `unbundled_register_result` · `b_home` | 系统/管理页，本 skill **拒绝**业务操作 |

### 登录/外部入口

| url_kind | 处理 |
|---|---|
| `login_fetch_cookie` · `login_asset` · `switch_asset` · `home_ka` · `tenant_select` · `tenant_create` · `channel_error` | 登录相关 — 改走 `auth-guard.md` |
| `quick_create_form` · `issue_trans` · `issue_create_open_usecase` · `story_create_open` · `jump_to_outer` · `light_share` · `ai_application_share` | 飞书内嵌入口，本 skill 通常不作为操作起点 |

### 错误兜底

| url_kind | 处理 |
|---|---|
| `lark_page_404` · `project_empty_page` · `route_loading` · `system_upgrade` | 错误页，**拒绝** |
| `unknown` | **拒绝**并要求用户提供详情页 URL 或直接描述任务 |

### 特殊字段校验

- `redirected_from` 非空 → 在回复中提一句"检测到 URL 已重定向：原路径 X，按归一化后 url_kind Y 处理"，让用户确认
- `is_resource=true` → 操作前在本轮回复里说明这是嵌套资源类型（例如缺陷下挂的子需求）。`work_item_type` 仍然只是 `api_name`，必须继续通过 `meegle workitem meta-types --project-key <project_key>` 映射成真实 `work_item_type_key`
