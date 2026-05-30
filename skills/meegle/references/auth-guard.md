# Deprecated Auth Guard

This repository's `skills/meegle` package no longer treats public OAuth/browser login as the default workflow.

For the private deployment path, use:

- [runtime-private-remote-mcp.md](runtime-private-remote-mcp.md)
- remote MCP SSO via `meegle auth login`
- `meegle doctor --format json`（按需诊断）

Treat `No project membership found` as a valid authenticated-but-not-authorized state. In that case, do not continue to business commands; the user must be added to a project-management work item by an administrator.

If someone explicitly needs a different non-private environment, handle that outside this skill through the generic CLI documentation. Public OAuth/browser login is out of scope for the default `meegle` skill in this repository.
