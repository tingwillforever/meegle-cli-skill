# 视图辅助命令

## Private CLI 差异

| upstream | private installed CLI |
|---|---|
| `view search` | `view search` 后本地筛选名称 |
| `view get` | `view get` |
| `view create-fixed` / `view update-fixed` | 当前不作为默认 skill 路径 |
| `view list-multi-project-workitems` | 当前 public CLI 不暴露，按需另行评审 |

视图 URL 路由先看 [url-kinds.md](url-kinds.md)。不要从 URL path 推断视图类型；必须先用 `view search` 读取 `view_type`。

---

## view search

列出空间和工作项类型下的视图配置，返回 `view_id`、名称和 `view_type`。

```bash
meegle view search \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --format json
```

`view_type` 只用于选择后续路径，不要仅凭 URL 中的 `storyView` / `multiProjectView` 判断。

## view get

读取固定视图或系统列表视图下的工作项。通常用于 `view_type=0` 或 `view_type=2`。

```bash
meegle view get \
  --project-key PROJ \
  --view-id VIEW_ID \
  --page-size 50 \
  --format json
```

当前 public CLI 不暴露 `view panoramic-items`。如果后续确认需要条件视图读取能力，应单独评审后再开放。
