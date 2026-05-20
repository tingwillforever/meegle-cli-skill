# Private Runtime: Installed CLI + Remote MCP

This repository's private deployment runtime is now:

- installed `meegle` CLI
- remote MCP Server
- SSO-backed session created by `meegle auth login`

It is not a local `stdio` / bundled `meegle-mcp` workflow.

## Required runtime model

- `meegle` installed from the published package
- built-in remote MCP endpoint, or an active profile override with `mcp_server_url`
- successful `meegle auth login`

## Preflight

Run this before business commands:

```bash
meegle doctor --format json
```

Expect:

- `overall_status: ok`
- `identity.status: ok`
- `details.mode: "http"`
- `details.host` present

If `doctor` fails, stop and fix runtime/auth/config first.

## Installation model

Typical private installation:

```bash
npm install -g @tingwillforever/meegle-cli
```

## Bootstrap

Default local acceptance:

```bash
meegle auth login
meegle auth status
```

Expected login outcomes:

- `Login successful`: remote MCP session is ready for business commands
- `No project membership found`: SSO passed, but the account is not a role-owner on any project-management work item in the configured space

In the `no project membership` case, ask an administrator to add the account to the relevant project-management work item's role members, then retry `meegle auth login`.

Temporary endpoint override:

```bash
meegle auth login --mcp-server-url https://mcp.example.com/mcp
```
