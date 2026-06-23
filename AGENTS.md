# AGENTS.md

## Repository Role

This repository is the public skill mirror for business-user installation and updates.

- Canonical CLI source: `/Users/ting/Develop/meegle-infra-workspace/meegle-cli/skills/meegle-cli`
- Canonical MCP source: `/Users/ting/Develop/meegle-infra-workspace/meegle-mcp/skills/meegle-mcp`
- Public mirror targets:
  - `/Users/ting/Develop/meegle-infra-workspace/meegle-skills/skills/meegle-cli`
  - `/Users/ting/Develop/meegle-infra-workspace/meegle-skills/skills/meegle-mcp`

This repository does not define Meegle CLI or MCP semantics. It republishes reviewed guidance from the canonical owning repositories.

## Mirror-Only Contract

Treat this repository as mirror-only:

- Do not invent or redefine public CLI or MCP semantics here.
- Do not update `skills/meegle-cli` or `skills/meegle-mcp` here first and then back-port to the canonical source.
- Do not publish private-only skills or references such as `meegle-debug`.
- Do not treat this repository as the source of truth for command surface, flag semantics, OAuth/runtime behavior, or execution workflow.

If a change affects public CLI surface, public MCP surface, projection guidance, `--help` / `inspect` guidance, flag semantics, OAuth/runtime behavior, or Agent execution workflow:

1. update the canonical source in `meegle-cli` or `meegle-mcp` first
2. review the canonical diff
3. sync into this repository
4. review the mirror diff before commit

## Allowed Change Types

Typical valid work in this repository:

- sync from canonical CLI or MCP skill
- review public-facing wording after canonical updates
- remove accidentally mirrored private-only files
- commit and publish the reviewed mirror state

If the requested work is actually changing CLI behavior or command guidance, move to `meegle-cli` and treat `skills/meegle-cli` there as the owning contract.

If the requested work is actually changing Agent-platform / direct-MCP behavior or command guidance, move to `meegle-mcp` and treat `skills/meegle-mcp` there as the owning contract.

## Public Commit Message Policy

This repository is user-facing. Commit messages in this repository should read
like public-facing product or documentation updates, not internal maintenance
notes.

When committing here:

- describe the user-visible result, not the sync mechanism
- prefer concise conventional-commit subjects such as `docs: ...`, `fix: ...`,
  or `chore: ...`
- avoid maintenance-language in the subject such as `sync`, `mirror`,
  `canonical`, `private`, or `upstream`

Prefer:

- `docs: update Meegle skill guidance`
- `docs: improve public installation instructions`
- `fix: remove private-only skill reference`

Avoid:

- `docs: sync canonical skill updates`
- `chore: sync skills from meegle-cli`
- `docs: update public mirror from private source`

If the underlying work was a sync from the canonical private source, the commit
message should still describe the resulting public-facing change.

## Push Policy

Direct push is allowed in this repository.

Agents do not need to open a branch or pull request unless the user explicitly
asks for that workflow. When pushing directly:

- keep the commit scope tight
- stage only intended files
- follow the public commit message policy above
- ensure the published state is reviewed before push

## Verification

Before completion, run:

```bash
/Users/ting/Develop/meegle-infra-workspace/scripts/sync-public-skill.sh --dry-run
```

For cross-repository CLI / MCP surface changes, also run:

```bash
cd /Users/ting/Develop/meegle-infra-workspace
/Users/ting/Develop/meegle-infra-workspace/scripts/check-architecture.sh
```
