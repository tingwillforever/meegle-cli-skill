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
rsync -a --delete --exclude='.DS_Store' \
  ../meegle-cli/skills/meegle/ \
  ./skills/meegle/
```

Review the diff before committing and pushing.
