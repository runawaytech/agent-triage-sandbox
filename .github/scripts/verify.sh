#!/usr/bin/env bash
# verify.sh — strict verification pipeline Agent B must pass before
# opening a PR. Steps: lint, typecheck, build, dev-server + Playwright
# smoke, collect screenshots.
#
# Assumes it runs in the repo root with Bun installed.
# Exits non-zero on any failure. Screenshots land in ./playwright-artifacts.

set -euo pipefail

STEP() { printf '\n=== %s ===\n' "$1"; }

STEP 'lint'
bun run lint

STEP 'typecheck'
bunx tsc -b

STEP 'build'
bun run build

STEP 'starting dev server'
bun run dev &
DEV_PID=$!
# Extend signal list so CI cancellation (SIGTERM/SIGINT from GitHub Actions)
# still reaps the background dev server instead of orphaning it.
trap 'kill $DEV_PID 2>/dev/null || true' EXIT INT TERM

# Wait for port 8080 to respond. 60s max.
bunx --bun wait-on 'http://localhost:8080' --timeout 60000

STEP 'playwright smoke'
mkdir -p playwright-artifacts
# Newer Playwright errors out when neither a config nor any specs exist, so
# only invoke it when there is something to run. Using `find` keeps this
# portable across bash 3.2 (macOS default) and bash 5.x (GHA runners).
if ls playwright.config.* >/dev/null 2>&1 \
  || find . -type d \( -name node_modules -o -name .git -o -name dist \) -prune -o \
       -type f \( -name '*.spec.ts' -o -name '*.test.ts' \) -print 2>/dev/null | grep -q .; then
  bunx playwright test --reporter=list
else
  echo 'No Playwright config or specs found — skipping.'
fi

STEP 'done'
