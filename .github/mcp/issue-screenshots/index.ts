#!/usr/bin/env bun
/**
 * Stdio MCP server exposing a single tool, `fetch_issue_screenshots`,
 * that downloads images linked in the current issue's body (from the
 * dedicated `screenshots` branch in the target repo) and returns them
 * as image content blocks.
 *
 * Protocol: JSON-RPC 2.0 over newline-delimited stdio. See the spec at
 * https://modelcontextprotocol.io/specification — we implement only the
 * bits Claude Code actually calls: initialize, initialized, tools/list,
 * tools/call. No external deps; we inline the protocol surface to keep
 * the workflow portable (no `bun install` in a sibling directory).
 */

const PROTOCOL_VERSION = '2024-11-05';

interface RpcRequest {
  jsonrpc: '2.0';
  id?: number | string;
  method: string;
  params?: unknown;
}

interface Content {
  type: 'text' | 'image';
  text?: string;
  data?: string;
  mimeType?: string;
}

function writeMessage(msg: unknown): void {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function respond(id: number | string | undefined, result: unknown): void {
  if (id === undefined) return; // notification
  writeMessage({ jsonrpc: '2.0', id, result });
}

function respondError(id: number | string | undefined, code: number, message: string): void {
  if (id === undefined) return;
  writeMessage({ jsonrpc: '2.0', id, error: { code, message } });
}

function log(msg: string): void {
  // stderr is the only channel that doesn't interfere with the protocol.
  process.stderr.write(`[issue-screenshots] ${msg}\n`);
}

/**
 * Extract raw.githubusercontent.com URLs that live on the `screenshots`
 * branch of any repo. We anchor on `/screenshots/` to avoid false matches
 * from embedded user images on arbitrary branches.
 */
export function extractScreenshotUrls(issueBody: string): string[] {
  const pattern = /https:\/\/raw\.githubusercontent\.com\/[^)\s]+\/screenshots\/[^)\s]+/g;
  return issueBody.match(pattern) ?? [];
}

interface Env {
  GITHUB_TOKEN: string;
  REPO: string;
  ISSUE_NUMBER: string;
}

function readEnv(): Env {
  const { GITHUB_TOKEN, REPO, ISSUE_NUMBER } = process.env;
  if (!GITHUB_TOKEN || !REPO || !ISSUE_NUMBER) {
    throw new Error(
      `missing required env: GITHUB_TOKEN=${!!GITHUB_TOKEN}, REPO=${!!REPO}, ISSUE_NUMBER=${!!ISSUE_NUMBER}`,
    );
  }
  return { GITHUB_TOKEN, REPO, ISSUE_NUMBER };
}

async function fetchIssueBody(env: Env): Promise<string> {
  const res = await fetch(`https://api.github.com/repos/${env.REPO}/issues/${env.ISSUE_NUMBER}`, {
    headers: {
      Authorization: `token ${env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'issue-screenshots-mcp',
    },
  });
  if (!res.ok) throw new Error(`GitHub issue fetch: ${res.status} ${await res.text()}`);
  const data = (await res.json()) as { body: string | null };
  return data.body ?? '';
}

async function fetchImage(url: string, token: string): Promise<Content> {
  const res = await fetch(url, {
    headers: { Authorization: `token ${token}`, 'User-Agent': 'issue-screenshots-mcp' },
  });
  if (!res.ok) throw new Error(`fetch image ${url}: ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  let bin = '';
  for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]);
  const base64 = btoa(bin);
  const mimeType = res.headers.get('content-type')?.split(';')[0] ?? 'image/png';
  return { type: 'image', data: base64, mimeType };
}

async function callFetchScreenshots(): Promise<Content[]> {
  const env = readEnv();
  const body = await fetchIssueBody(env);
  const urls = extractScreenshotUrls(body);
  if (urls.length === 0) {
    return [{ type: 'text', text: 'No screenshots found in this issue.' }];
  }
  log(`extracted ${urls.length} screenshot URL(s)`);
  const images: Content[] = [];
  for (const url of urls) {
    try {
      images.push(await fetchImage(url, env.GITHUB_TOKEN));
    } catch (err) {
      images.push({
        type: 'text',
        text: `Failed to fetch ${url}: ${err instanceof Error ? err.message : String(err)}`,
      });
    }
  }
  images.unshift({
    type: 'text',
    text: `Fetched ${urls.filter((_, i) => images[i + 1]?.type === 'image').length} screenshot(s) from issue #${env.ISSUE_NUMBER}.`,
  });
  return images;
}

async function handle(req: RpcRequest): Promise<void> {
  switch (req.method) {
    case 'initialize':
      respond(req.id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: { tools: {} },
        serverInfo: { name: 'issue-screenshots', version: '0.1.0' },
      });
      return;
    case 'initialized':
    case 'notifications/initialized':
      return; // notification, no response
    case 'tools/list':
      respond(req.id, {
        tools: [
          {
            name: 'fetch_issue_screenshots',
            description:
              'Fetch the screenshots (if any) attached to the current GitHub issue. Returns image content blocks the model can see directly. Call this when the issue body contains a markdown image link pointing at a GitHub raw URL on the `screenshots` branch.',
            inputSchema: { type: 'object', properties: {}, required: [] },
          },
        ],
      });
      return;
    case 'tools/call': {
      const params = req.params as { name?: string } | undefined;
      if (params?.name !== 'fetch_issue_screenshots') {
        respondError(req.id, -32601, `Unknown tool: ${params?.name}`);
        return;
      }
      try {
        const content = await callFetchScreenshots();
        respond(req.id, { content });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        respond(req.id, {
          content: [{ type: 'text', text: `Error: ${message}` }],
          isError: true,
        });
      }
      return;
    }
    default:
      respondError(req.id, -32601, `Method not found: ${req.method}`);
  }
}

function readLoop(): void {
  let buffer = '';
  process.stdin.setEncoding('utf-8');
  process.stdin.on('data', (chunk: string) => {
    buffer += chunk;
    let newlineIndex: number;
    while ((newlineIndex = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, newlineIndex).trim();
      buffer = buffer.slice(newlineIndex + 1);
      if (!line) continue;
      try {
        const req = JSON.parse(line) as RpcRequest;
        void handle(req);
      } catch (err) {
        log(`invalid JSON-RPC: ${err}`);
      }
    }
  });
  process.stdin.on('end', () => {
    process.exit(0);
  });
}

if (import.meta.main) {
  log('starting');
  readLoop();
}
