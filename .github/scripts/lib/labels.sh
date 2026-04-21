#!/usr/bin/env bash
# labels.sh — thin wrappers around `gh` for label manipulation.
# Sourced by other scripts. Exposes: add_label, remove_label, has_label.
#
# Library policy: we do NOT set -euo pipefail at top level because sourcing
# this file must not mutate the caller's shell options. Each function is
# responsible for its own error propagation via explicit return codes.

# add_label <issue-or-pr-number> <label>
# Exits 0 on success; non-zero on gh failure.
add_label() {
  local number="$1"
  local label="$2"
  gh api -X POST "repos/${GITHUB_REPOSITORY}/issues/${number}/labels" \
    -f "labels[]=${label}" >/dev/null
}

# remove_label <issue-or-pr-number> <label>
# Always returns 0 (no error if the label isn't set).
remove_label() {
  local number="$1"
  local label="$2"
  gh api -X DELETE \
    "repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${label}" \
    >/dev/null 2>&1 || true
}

# has_label <issue-or-pr-number> <label>
# Returns 0 if present, 1 if absent. Designed for `if has_label N L; then`
# usage even under `set -e` in the caller — we explicitly return instead of
# letting `grep`'s exit code bubble.
has_label() {
  local number="$1"
  local label="$2"
  local labels
  labels=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${number}/labels" --jq '.[].name') || return 2
  if printf '%s\n' "$labels" | grep -Fxq "${label}"; then
    return 0
  else
    return 1
  fi
}
