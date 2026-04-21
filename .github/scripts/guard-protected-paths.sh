#!/usr/bin/env bash
# guard-protected-paths.sh
# If any changed file matches PROTECTED_RE, post a PR comment, label
# the PR needs-human, and exit non-zero. Used in Agent B workflow
# AFTER B has pushed its branch and BEFORE the PR is opened.
#
# Invocation:
#   bash .github/scripts/guard-protected-paths.sh <base-ref> <pr-number>
# With "--lib-only" only exports PROTECTED_RE (for tests). Does not execute.

set -euo pipefail

# POSIX ERE. tsconfig[^/]*\.json covers tsconfig.json, tsconfig.app.json,
# tsconfig.node.json without matching tsconfig-notes.md (no dot before ext).
PROTECTED_RE='^(package\.json|bun\.lock|vite\.config\.ts|tsconfig[^/]*\.json|\.github/.*|functions/.*|CLAUDE\.md|AGENTS\.md|\.env(\..+)?)$'

if [ "${1-}" = "--lib-only" ]; then
  export PROTECTED_RE
  return 0 2>/dev/null || exit 0
fi

BASE_REF="${1:?base-ref required}"
PR_NUMBER="${2:?pr-number required}"

# Load label helpers EARLY so any sourcing failure aborts before we fire
# any PR-side effects. If this source fails under set -e, we exit before
# posting comments or trying to label a PR we can't follow up on.
# shellcheck source=.github/scripts/lib/labels.sh
source "$(dirname "$0")/lib/labels.sh"

# Ensure the base ref is present in case the runner was shallow-cloned.
# On a full checkout this is a no-op. We swallow errors because repeated
# fetches on an already-up-to-date ref are fine to skip.
git fetch --no-tags --depth=0 origin "$BASE_REF" >/dev/null 2>&1 \
  || git fetch --no-tags origin "$BASE_REF" >/dev/null 2>&1 \
  || true

CHANGED="$(git diff --name-only "origin/${BASE_REF}...HEAD")"
MATCHED="$(echo "$CHANGED" | grep -E "$PROTECTED_RE" || true)"

if [ -n "$MATCHED" ]; then
  BODY=$(printf '❌ Agent B attempted to modify protected paths:\n\n```\n%s\n```\n\nLabeling `needs-human`.' "$MATCHED")
  gh pr comment "$PR_NUMBER" --body "$BODY"
  add_label "$PR_NUMBER" needs-human
  remove_label "$PR_NUMBER" ai-pr
  exit 1
fi
