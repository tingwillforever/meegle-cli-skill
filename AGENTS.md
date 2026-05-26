# AGENTS.md

## Repository Role

This repository is the public skill mirror for business-user installation and updates.

- Canonical private source: `/Users/ting/Develop/meegle-workspace/meegle-cli/skills/meegle`
- Public mirror target: `/Users/ting/Develop/meegle-workspace/meegle-cli-skill/skills/meegle`

This repository does not define Meegle CLI semantics. It republishes reviewed guidance from the canonical private source.

## Mirror-Only Contract

Treat this repository as mirror-only:

- Do not invent or redefine public CLI semantics here.
- Do not update `skills/meegle` here first and then back-port to the canonical source.
- Do not publish private-only skills or references such as `meegle-debug`.
- Do not treat this repository as the source of truth for command surface, flag semantics, or execution workflow.

If a change affects public CLI surface, projection guidance, `--help` / `inspect` guidance, flag semantics, or Agent execution workflow:

1. update the canonical source in `meegle-cli` first
2. review the canonical diff
3. sync into this repository
4. review the mirror diff before commit

## Allowed Change Types

Typical valid work in this repository:

- sync from canonical private skill
- review public-facing wording after canonical updates
- remove accidentally mirrored private-only files
- commit and publish the reviewed mirror state

If the requested work is actually changing CLI behavior or command guidance, move to `meegle-cli` and treat `skills/meegle` there as the owning contract.

## Verification

Before completion, run:

```bash
cd /Users/ting/Develop/meegle-workspace/meegle-cli-skill
./sync-skills.sh --dry-run
```

For cross-repository CLI surface changes, also run:

```bash
cd /Users/ting/Develop/meegle-workspace
/Users/ting/Develop/meegle-workspace/scripts/check-architecture.sh
```
