#!/usr/bin/env bash
# Sync skills from ../meegle-cli/skills to ./skills, with optional exclusions.
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
SRC_DIR="$(cd "${SCRIPT_DIR}/../meegle-cli/skills" && pwd)"
DST_DIR="${SCRIPT_DIR}/skills"

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

# Build rsync exclude args
RSYNC_EXCLUDES=("--exclude=.DS_Store")
for pattern in "${EXCLUDES[@]}"; do
  RSYNC_EXCLUDES+=("--exclude=${pattern}")
done

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

echo ""
$DRY_RUN && echo "Dry run complete." || echo "Sync complete."
