# 附件域

当前私有 CLI 的附件域以 **MCP 实际工具** 为准，不沿用 upstream 的两段式 `prepare-*` / `+upload` / `+download` 协议抽象。

可公开使用的 attachment 命令：

- `attachment upload-file`
- `attachment upload`
- `attachment download`
- `attachment delete`

附件命令不是默认高频路径。执行前先运行：

```bash
meegle inspect attachment.upload-file --format json
meegle inspect attachment.upload --format json
meegle inspect attachment.download --format json
meegle inspect attachment.delete --format json
```

确认参数形态后再执行。不要复用 upstream 的 `prepare-*` 或 `+upload` / `+download` 示例。

`--file` 始终填写当前 CLI 客户端可读取的本机文件路径。安装版 CLI 会在本机读取该文件，并把文件内容发送给共用远端 MCP Server；普通用户和 Agent 不需要启动本地 MCP Server，也不要手工传 base64 或服务端本地路径。

上传前可用 `--dry-run --format json` 预览 normalized request。附件上传的 dry-run 只展示本机路径、文件名、大小、内容类型和 `data-url-base64` 传输编码摘要，不输出文件内容或 base64 数据。

如果真实调用报远端 `ENOENT`，且错误里出现 `/var/folders/...`、`/Users/...`、`/tmp/...png` 等 CLI 本机路径，说明当前安装版 CLI 未包含本机文件物化修复，仍把本机路径交给远端 MCP 读取。此时先升级或重新构建安装当前源码版，再用 `--dry-run --format json` 确认输出里有 `file_transfer.encoding = "data-url-base64"`。

---

## attachment upload-file

上传文件到项目空间，适合富文本图片、通用文件等不直接绑定工作项附件字段的场景。

```bash
meegle attachment upload-file \
  --project-key PROJ \
  --fileName image.png \
  --file /absolute/path/image.png \
  --format json
```

dry-run 示例：

```bash
meegle attachment upload-file \
  --project-key PROJ \
  --fileName image.png \
  --file /absolute/path/image.png \
  --dry-run \
  --format json
```

## attachment upload

上传附件到已有工作项字段。当前私有 CLI 需要绑定工作项上下文，并且必须用 `--field-key` 或 `--field-alias` 指明附件字段；两者恰好传一个，推荐使用 `--field-key`。

字段 key 只能来自当前空间 / 工作项类型的字段元数据，不要把历史 case 里的 `field_*` 复用到其它空间或类型。上传前先定位 `field_type_key == "multi_file"` 的字段：

```bash
meegle workitem meta-fields \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --output-select field_key,field_name,field_alias,field_type_key \
  --format json
```

从返回的 `data[]` 中选择 `field_type_key == "multi_file"` 的字段，优先把它的 `field_key` 传给 `attachment upload`。如果没有唯一附件字段，不要猜，先让用户确认要挂到哪个附件字段。

```bash
meegle attachment upload \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --field-key field_xxx \
  --fileName a.pdf \
  --file /absolute/path/a.pdf \
  --format json
```

dry-run 示例：

```bash
meegle attachment upload \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --field-key field_xxx \
  --fileName a.pdf \
  --file /absolute/path/a.pdf \
  --dry-run \
  --format json
```

如果缺少 `--field-key` 和 `--field-alias`，CLI 会直接返回 `FIELD_KEY_OR_ALIAS_REQUIRED`，不会发起远端上传。此时回到上面的 `workitem meta-fields` 步骤定位 `multi_file` 字段。不要同时传 `--field-key` 和 `--field-alias`；同时传入会返回 `FIELD_KEY_AND_ALIAS_CONFLICT`。

返回中的 `file_token` / 文件元数据用于后续字段写入。附件字段通常是覆盖语义；追加附件时先读取旧值，合并后再写回。

## attachment download

按附件 UUID 下载已有工作项附件。`uuid` 必须来自接口返回，不要从页面 URL 手工拼接。

```bash
meegle attachment download \
  --project-key PROJ \
  --work-item-type-key TYPE_KEY \
  --work-item-id 12345 \
  --uuid ATTACHMENT_UUID \
  --format json
```

## attachment delete

按 UUID 从工作项附件中删除文件。**destructive 命令，必须带 `--confirm` 才能执行**；使用前应确认目标工作项、字段和待删 UUID 列表。

```bash
meegle attachment delete \
  --project-key PROJ \
  --work-item-id 12345 \
  --field-key field_xxx \
  --uuids '["uuid-a","uuid-b"]' \
  --confirm \
  --format json
```

上传/下载属于低频路径；`delete` 属于 destructive 命令，只在用户明确要求删除附件时使用，并提示删除不可恢复。
