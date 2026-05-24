#!/usr/bin/env bash
# Sync the public meegle skill from ../meegle-cli/skills/meegle to ./skills/meegle,
# with optional exclusions.
#
# Usage:
#   ./sync-skills.sh [--exclude <pattern>] [--exclude <pattern>] ...
#   ./sync-skills.sh --dry-run
#
# Examples:
#   ./sync-skills.sh
#   ./sync-skills.sh --exclude "field-cache-bug-new.md"
#   ./sync-skills.sh --exclude "*.DS_Store" --exclude "references/misc.md"
#   ./sync-skills.sh --dry-run --exclude "field-cache-bug-new.md"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/../meegle-cli/skills/meegle" && pwd)"
DST_DIR="${SCRIPT_DIR}/skills/meegle"
PRIVATE_ONLY_FILES=("references/field-cache-bug-new.md")

DRY_RUN=false
EXCLUDES=()

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --exclude)
      [[ -z "${2:-}" ]] && { echo "Error: --exclude requires a value" >&2; exit 1; }
      EXCLUDES+=("$2")
      shift 2
      ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: source directory not found: $SRC_DIR" >&2
  exit 1
fi

# Build rsync exclude args. Bash 3.2 with set -u treats empty array expansion as
# unbound, so only expand EXCLUDES when at least one custom pattern exists.
# Private field caches belong only to the canonical private skill; never publish
# them to the business-user mirror.
RSYNC_EXCLUDES=("--exclude=.DS_Store")
for path in "${PRIVATE_ONLY_FILES[@]}"; do
  RSYNC_EXCLUDES+=("--exclude=${path}")
done
if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
  for pattern in "${EXCLUDES[@]}"; do
    RSYNC_EXCLUDES+=("--exclude=${pattern}")
  done
fi

echo "Source : $SRC_DIR"
echo "Dest   : $DST_DIR"
if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
  echo "Exclude: ${EXCLUDES[*]}"
fi
$DRY_RUN && echo "(dry run — no files will be written)"
echo ""

RSYNC_FLAGS=(-av --delete)
$DRY_RUN && RSYNC_FLAGS+=(--dry-run)

rsync "${RSYNC_FLAGS[@]}" "${RSYNC_EXCLUDES[@]}" "${SRC_DIR}/" "${DST_DIR}/"

# rsync --delete does not remove excluded files already present in the
# destination, so prune private-only files explicitly to keep the public
# mirror self-healing.
for path in "${PRIVATE_ONLY_FILES[@]}"; do
  target="${DST_DIR}/${path}"
  if [[ "$DRY_RUN" == true ]]; then
    if [[ -e "$target" ]]; then
      echo "Would remove private-only file: $target"
    fi
    continue
  fi
  rm -f "$target"
done

echo ""
$DRY_RUN && echo "Dry run complete." || echo "Sync complete."
