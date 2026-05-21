# CLI Guide

## Command shape

```bash
meegle <resource> <method> [flags] --format json
```

Always prefer `--format json` unless the user explicitly wants another format.

## Discovery

When parameter shape is uncertain:

```bash
meegle inspect
meegle inspect workitem.create
meegle inspect comment.add
```

Treat inspect output as the source of truth over older examples and documentation.
