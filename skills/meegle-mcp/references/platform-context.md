# Platform Context

本文件定义业务方 Agent 平台接入 Meegle MCP 时建议提供的宿主上下文。它不是 public MCP tool contract，而是让 MCP 使用体验接近 CLI 的平台增强层。

## 四类宿主能力

### 当前登录用户上下文

来源：

- bearer session 绑定的 Meegle 用户
- MCP session 中可被 `meegle.user.query` + `current_login_user()` 解析的用户

使用规则：

- 需要 user key 时优先调用 `meegle.user.query`。
- 平台已提供 user key 时仍可作为上下文 hint，但写操作前以 MCP tool 返回为准。

### bearer session / 浏览器登录态

来源：

- Agent 平台接入层保存的 bearer session
- 浏览器 OAuth / SSO 登录态

使用规则：

- skill 不自己登录，也不读取浏览器 cookie。
- authz 拒绝时停止并说明权限不足，不改用隐藏工具。

### 当前页面或 URL 的结构化锚点

推荐平台传入结构：

```json
{
  "project_key": "cbg_product_develop",
  "work_item_type_key": "type_key",
  "work_item_id": 123456,
  "view_id": "view_xxx",
  "chart_id": "chart_xxx",
  "release_id": "123456",
  "recordID": "record_xxx"
}
```

使用规则：

- 有结构化锚点时，可直接进入对应 SOP。
- 只有原始 URL 且平台没有解析结果时，暴露 capability gap，不从 URL 路径段猜参数。
- URL 中的工作项类型若只是 api_name，仍需用 `meegle.space.types` 转成真实 type key。

### 默认 project_key / 当前空间上下文

来源：

- MCP session 暴露的唯一 `projectKeys`
- 平台当前空间选择器
- 用户明确指定的 `project_key`

使用规则：

- session 只有一个 `projectKeys` 时，直接作为默认 `project_key`。
- 多个候选且用户未明确指定时，列候选让用户选。
- 不把可读空间名、simple name 或 URL 片段未经确认地称为底层 project key。

## Stop Conditions

缺少以下上下文时停止：

- URL 场景缺少结构化锚点。
- 发布计划部署任务缺少本次请求明确的 release context。
- 写操作缺少目标对象三元组。
- 当前 session authz 拒绝。

停止时说明需要平台补什么结构化字段，不要继续试探。
