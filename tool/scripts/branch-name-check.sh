#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD)
PATTERN='^(feature|refactor|fix|chore|build|style|docs|release)/.+'

if echo "$BRANCH" | grep -qE '^(main|master|develop|HEAD)$'; then
  exit 0
fi

if ! echo "$BRANCH" | grep -qE "$PATTERN"; then
  echo "ERROR: Branch name '$BRANCH' does not follow the required naming convention."
  echo ""
  echo "Expected pattern: <prefix>/<description>"
  echo "Allowed prefixes: feature, refactor, fix, chore, build, style, docs, release"
  echo ""
  echo "Examples:"
  echo "  feature/add-keystore-verify"
  echo "  fix/retry-on-timeout"
  echo "  chore/update-deps"
  exit 1
fi

exit 0
