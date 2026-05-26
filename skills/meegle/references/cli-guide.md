# CLI Guide

## 命令形态

```bash
meegle <resource> <method> [flags] --format json
```

默认优先使用 `--format json`，除非用户明确需要 table 或 ndjson。

## 命令发现

参数 shape 不确定时，以 live CLI 为准：

```bash
meegle inspect
meegle inspect workitem.create --format json
meegle inspect comment.add --format json
```

当历史示例与 inspect 不一致时，优先相信 inspect 输出。

准备使用 `--select` 时，先看 `inspect --format json` 里的 projection metadata：

- `projection.backend_select_supported`
- `projection.backend_request_path`
- `projection.local_projection_flag`
- `projection.local_path_hint`（如 `view items` 的 `data.<field>`）
- `decision_guidance.projection_mode`
- `decision_guidance.wrapper_path_hint`
- `decision_guidance.dry_run_recommended`

## Flag 语义层

全局 flag 不是同一类能力。先判断语义层，再判断能否影响后端请求。

| 语义层 | 代表 flag | 是否进入后端业务请求 | 使用原则 |
|---|---|---:|---|
| Request input | 命令自身 flags、`--params/-P`、`--set`、支持 backend projection 的 `--select` | 是 | 用于过滤、分页、写入、字段 projection 等请求语义 |
| Execution control | `--dry-run`、`--refresh` | 否 | 控制 CLI 执行流程、认证刷新或请求预览 |
| Output display | `--format`、`--envelope`、`--verbose`、`--output-select` | 否 | 控制本地输出形状或诊断信息，不替代后端过滤 |
| Compat / lower-level | `--fields` 等 API-native 参数 | 是 | 仅在命令特定兼容场景使用，不作为默认产品化 UX |

### Structured request input

`--params/-P` 与 `--set` 用于补充 request input：

```bash
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --params '{"page_size":50}' \
  --set 'created_at.start=1771603200000' \
  --set 'created_at.end=1779379199000' \
  --dry-run \
  --format json
```

优先级稳定为：

```text
--params/-P < --set < 具体命令 flag
```

涉及嵌套对象、时间范围、分页、projection 或写操作时，先加 `--dry-run`，检查输出里的 `.params`，确认预期字段已经进入后端请求。

verified command 的 dry-run 如果发现明显未知顶层参数，现在会直接 fail fast，而不是继续输出看似正常的 payload。遇到这种情况时：

1. 先修正 flag 名或 `--params` 顶层 key
2. 若 CLI 给出高置信度 `did-you-mean`，优先按该建议改写
3. 用 `meegle inspect <resource>.<method> --format json` 对照当前 public flag 集
4. 如怀疑本地 schema 过期，再加 `--refresh`

### Backend projection 与本地输出裁剪

`--select` 与 `--output-select` 不是同义词：

| 目标 | 使用 | 效果 |
|---|---|---|
| 减少后端返回字段 | `--select id,name,work_item_status` | 进入后端请求；当前首批支持 `workitem get`、`workitem search-by-params` |
| 只减少本地展示字段 | `--output-select id,name,work_item_status` | 后端仍返回原始结果，CLI 在响应后裁剪展示 |

判断某个命令能不能用 `--select`，不要凭经验猜；先看 `inspect --format json` 的 `projection.backend_select_supported`。

示例：支持 backend projection 的命令。

```bash
meegle workitem search-by-params \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --search-group '{"conjunction":"AND","search_params":[],"search_groups":[]}' \
  --select id,name,work_item_status,created_at \
  --dry-run \
  --format json
```

dry-run 中应看到 `params.data.fields`：

```json
{
  "data": {
    "fields": ["id", "name", "work_item_status", "created_at"]
  }
}
```

示例：只做本地展示裁剪。

```bash
meegle workitem search-filter \
  --project-key PROJ \
  --work-item-type-keys '["TYPE_KEY"]' \
  --page-size 20 \
  --output-select id,name,work_item_status,created_at \
  --format json
```

如果在非 projection-capable 命令上使用 `--select`：

- CLI 会直接返回错误，不再做本地裁剪 fallback。
- 错误 remediation 会同时指向 `meegle inspect <resource>.<method> --format json` 和与该命令返回形状匹配的 `--output-select` 改写方式。
- 目标是本地展示裁剪：改用 `--output-select`。
- 目标是减少后端字段：改用 `workitem get` / `workitem search-by-params` 等支持 backend projection 的命令，或移除 projection 诉求。

说明：当前 backend projection 在 `workitem get` / `workitem search-by-params` 上主要会收敛 `fields[]` 自定义字段集合；固定顶层字段仍可能按接口契约返回。

`--output-select` 的路径需要匹配真实响应形状：

- 列表响应或 `{data:[...]}` wrapper：通常可以直接写 `id,name,work_item_status`，CLI 会自动投影到数组元素。
- object-wrapper 响应：需要显式写 wrapper 路径，例如 `view items` 用 `--output-select data.name,data.view_id,data.work_item_id_list`。
- 对已知 object-wrapper 命令，如果误写成 bare key，CLI 会返回 wrapper-aware remediation，并提示你用 `inspect` 确认 `data.xxx` 路径。

### `--fields` 兼容边界

`--fields` 是 API-native compatibility input，不是默认 projection UX。

- 命令支持 backend projection 时，优先使用 `--select`。
- 只有当用户明确需要底层 API-native `fields` 参数，或排障需要直连底层参数时，才使用 `--fields`。
- 不要在同一命令中同时传 `--select` 与 `--fields`；CLI 会返回确定性冲突错误。

### 输出展示 flag

`--format`、`--envelope`、`--verbose`、`--output-select` 都属于本地输出展示层：

- `--format json`：默认稳定机器可读输出。
- `--format ndjson`：适合流式或逐行处理。
- `--format table`：适合人类浏览。
- `--envelope`：输出 `{data, meta, error}` wrapper；用于需要响应 envelope 的脚本或排障。
- `--verbose`：增加 table 细节或错误诊断；不要把它当成 JSON data shape contract。
- `--output-select`：响应返回后裁剪展示字段；不改变后端请求。

`--dry-run` 验证请求构造，不验证这些输出展示 flag 的最终渲染效果。
