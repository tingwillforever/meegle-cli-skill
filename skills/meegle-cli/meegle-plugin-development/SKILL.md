---
name: meegle-plugin-development
description: Use when building, configuring, diagnosing, or extending Meegle plugins, including full plugin workflows, atomic `lpm` operations, and backend-integration knowledge for webhook/OpenAPI/proxy work.
---

# Meegle Plugin Development

## Overview

Umbrella skill for Meegle plugin development. It covers three layers that belong to the same maintainer-facing class:
- **Workflow orchestration** for end-to-end plugin work
- **Atomic CLI operations** with `lpm`
- **Backend integration knowledge** for self-hosted service code

Use this umbrella when the user is working on a Meegle plugin as a product/development artifact, not when they are querying Meegle business data itself.

## Routing

### Full plugin workflow

Use when the user wants to:
- create a plugin project
- add or modify plugin features
- change point configuration
- polish metadata
- publish or release a plugin
- coordinate frontend/plugin work with backend handoff

Primary reference:
- `references/meegle-plugin-workflow.md`

### Atomic `lpm` command work

Use when the user wants a single command-level operation or diagnosis inside an existing plugin project, such as:
- start local preview
- build or package
- sync local/remote config
- inspect schema or categories
- check/apply permissions
- diagnose plugin-project state or common CLI issues

Primary reference:
- `references/meegle-plugin-cli.md`

### Backend integration knowledge

Use when the task is specifically about the self-hosted backend half of a plugin:
- webhook receiving and signature verification
- OpenAPI permission/scope interpretation
- OpenAPI request/response contract lookup
- writing back to work items / AI nodes / AI fields
- implementing `/api/proxy/*` style server endpoints

Primary reference:
- `references/meegle-plugin-backend.md`

## Boundaries

- For Meegle business-data operations like work items, views, workflow states, comments, and release/deploy tasks, use the separate Meegle business-data skill rather than this umbrella.
- For one-shot CLI command syntax inside plugin work, prefer the CLI subsection rather than replaying the whole workflow.
- For platform facts, treat the linked references and live tools as authoritative rather than memory.

## Related support files

- `references/meegle-plugin-workflow.md`
- `references/meegle-plugin-cli.md`
- `references/meegle-plugin-backend.md`
