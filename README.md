# Meegle CLI Skill

Public distribution repository for the `meegle` agent skill.

This repository mirrors the `skills/meegle` directory from the private
`meegle-cli` repository. Updates are synced manually when the CLI skill changes.

## Install

```bash
npx -y skills add https://github.com/tingwillforever/meegle-cli-skill --skill meegle -g -y
```

## Contents

- `skills/meegle/SKILL.md`
- `skills/meegle/references/`

## Manual Sync

From a local checkout with both repositories side by side:

```bash
./sync-skills.sh --dry-run
./sync-skills.sh
```

`sync-skills.sh` syncs only the public `skills/meegle/` directory into this
repository's `skills/meegle/`. Review the diff before committing and pushing.
