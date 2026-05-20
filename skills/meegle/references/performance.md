# 性能与并发调用指南

本文件收录减少延迟的工程性规则。核心协议（字段格式、错误自愈）仍在 SKILL.md 主文件中。

## 并行调用

无依赖的命令调用应并行发起，有依赖则必须串行。

**必须串行**（前者输出是后者输入）：
- `space list` → `workitem meta-types` → `workitem meta-create-fields`
- `workitem get` → `workflow list-state-transitions` / `workitem update`
- `workitem meta-create-fields` → `workitem create`

**可并行**：
- 多种工作项类型的 `workitem meta-create-fields`
- 各条件的 count 查询、多人排期分批查询

## 大结果处理

- **分批查询**：分页或多人查询时按接口限制拆批，不要一次拉取过大结果
- **精简 SELECT**：只选必要字段，避免富文本等大体积字段
- **按需翻页**：先读首页获取总数，按需翻页
