#!/usr/bin/env bash
# round-counter.sh — read label names from stdin, one per line.
# Emit the highest N for rebuttal-round-N, or 0 if none present.
set -euo pipefail

max=0
while IFS= read -r line; do
  case "$line" in
    rebuttal-round-[123])
      n="${line#rebuttal-round-}"
      if [ "$n" -gt "$max" ]; then max="$n"; fi
      ;;
  esac
done
echo "$max"
