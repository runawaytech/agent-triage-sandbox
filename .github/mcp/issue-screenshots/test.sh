#!/usr/bin/env bash
# Smoke test for the screenshot URL extraction — runs without launching the
# full MCP server. Requires bun.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bun --print "
import { extractScreenshotUrls } from '${SCRIPT_DIR}/index.ts';

const cases: [string, string[]][] = [
  ['empty body', []],
  [
    'body with one screenshot',
    ['https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-1/a.png'],
  ],
  [
    'body with two screenshots and other URLs',
    [
      'https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-5/a.png',
      'https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-5/b.jpg',
    ],
  ],
  ['body with raw URL on non-screenshots branch', []],
];

const bodies: Record<string, string> = {
  'empty body': '',
  'body with one screenshot':
    '**Title:** X\n\n![screenshot](https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-1/a.png)',
  'body with two screenshots and other URLs': [
    'See this:',
    '![1](https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-5/a.png)',
    'Also this:',
    '![2](https://raw.githubusercontent.com/o/r/screenshots/.screenshots/issue-5/b.jpg)',
    'And this unrelated repo:',
    '![unrelated](https://example.com/image.png)',
  ].join('\n'),
  'body with raw URL on non-screenshots branch':
    '![other](https://raw.githubusercontent.com/o/r/main/README.md)',
};

let pass = 0, fail = 0;
for (const [name, expected] of cases) {
  const got = extractScreenshotUrls(bodies[name] ?? '');
  const ok = JSON.stringify(got) === JSON.stringify(expected);
  if (ok) { console.log('PASS', name); pass++; }
  else { console.log('FAIL', name, 'expected', expected, 'got', got); fail++; }
}
console.log(\`Total: \${pass} passed, \${fail} failed\`);
process.exit(fail === 0 ? 0 : 1);
"
