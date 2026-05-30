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

## attachment upload

上传附件到已有工作项字段。当前私有 CLI 需要绑定工作项上下文。

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
  --uuids uuid-a \
  --uuids uuid-b \
  --confirm \
  --format json
```

上传/下载属于低频路径；`delete` 属于 destructive 命令，只在用户明确要求删除附件时使用，并提示删除不可恢复。
