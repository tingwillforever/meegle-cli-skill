# CLI Guide

## Runtime assumption

This guide is for the installed private package path.

## Node requirement

The installed CLI is a remote MCP client only. Node.js is required to install
and launch the published package, but no bundled local `meegle-mcp` runtime is
part of the supported private path.

## Command shape

Use:

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

Treat inspect output as the source of truth over older examples.

## Current private-skill rule

For this repository's Meegle skill:

- prefer installed-package execution
- prefer `doctor` before business commands
- prefer verified commands
