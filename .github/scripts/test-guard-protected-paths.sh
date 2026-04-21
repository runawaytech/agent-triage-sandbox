#!/usr/bin/env bash
# Tests the regex used by guard-protected-paths.sh.
# Source the guard so we can access PROTECTED_RE without invoking side effects.
set -euo pipefail
GUARD="$(dirname "$0")/guard-protected-paths.sh"
# shellcheck disable=SC1090
source "$GUARD" --lib-only

fail=0
assert_match() {
  if ! echo "$1" | grep -Eq "$PROTECTED_RE"; then
    echo "FAIL: expected MATCH for '$1'" >&2; fail=1
  fi
}
assert_no_match() {
  if echo "$1" | grep -Eq "$PROTECTED_RE"; then
    echo "FAIL: expected NO MATCH for '$1'" >&2; fail=1
  fi
}

# Must be protected:
assert_match 'package.json'
assert_match 'bun.lock'
assert_match 'vite.config.ts'
assert_match 'tsconfig.json'
assert_match 'tsconfig.app.json'
assert_match '.github/workflows/ci.yml'
assert_match 'functions/contact.ts'
assert_match 'CLAUDE.md'
assert_match 'AGENTS.md'
assert_match '.env'
assert_match '.env.local'
assert_match '.env.production'

# Must NOT be protected:
assert_no_match 'src/App.tsx'
assert_no_match 'docs/env-guide.md'
assert_no_match '.environment-notes.md'
assert_no_match 'scripts/package.json.example'
assert_no_match 'tsconfig-notes.md'
assert_no_match 'src/functions/helper.ts'

if [ "$fail" -eq 0 ]; then echo "All guard regex assertions passed"; else exit 1; fi
