#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG_FILE="${1}"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

PATTERN='^(feat|fix|chore|refactor|test|docs|style|ci|perf|build|revert)(\(.+\))?: .+'

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo ""
  echo "Expected: <type>(<scope>): <description>"
  echo "Allowed types: feat, fix, chore, refactor, test, docs, style, ci, perf, build, revert"
  echo ""
  echo "Examples:"
  echo "  feat(keystore): add verify command"
  echo "  fix: resolve crash on missing config"
  echo "  chore: update dependencies"
  echo ""
  echo "Your message: $COMMIT_MSG"
  exit 1
fi

if echo "$COMMIT_MSG" | grep -qP '[А-ЯҐЄІЇа-яґєії]'; then
  echo "ERROR: Commit message contains Cyrillic characters. English only."
  exit 1
fi

exit 0
