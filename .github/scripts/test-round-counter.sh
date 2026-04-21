#!/usr/bin/env bash
# test-round-counter.sh — TDD for round-counter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUND_SCRIPT="$SCRIPT_DIR/round-counter.sh"

pass=0; fail=0
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS %s\n' "$label"; pass=$((pass+1))
  else
    printf 'FAIL %s — expected %q, got %q\n' "$label" "$expected" "$actual"; fail=$((fail+1))
  fi
}

# Test: no rebuttal labels → round 0
got=$(printf 'ai-pr\nagent-working\n' | bash "$ROUND_SCRIPT")
assert_eq "no rebuttal labels → 0" "0" "$got"

# Test: rebuttal-round-1 → round 1
got=$(printf 'ai-pr\nrebuttal-round-1\n' | bash "$ROUND_SCRIPT")
assert_eq "round-1 label → 1" "1" "$got"

# Test: round-2 and round-1 both present → reports highest (2)
got=$(printf 'rebuttal-round-1\nrebuttal-round-2\n' | bash "$ROUND_SCRIPT")
assert_eq "highest round wins" "2" "$got"

# Test: round-3 → 3
got=$(printf 'rebuttal-round-3\n' | bash "$ROUND_SCRIPT")
assert_eq "round-3 → 3" "3" "$got"

# Test: empty input → 0
got=$(printf '' | bash "$ROUND_SCRIPT")
assert_eq "empty input → 0" "0" "$got"

printf 'Total: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = "0" ]
