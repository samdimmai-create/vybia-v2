#!/usr/bin/env node
// S9.1 — DevTools (CDP) screenshot client for the VISIBLE Chrome window.
//
// Connects to a Chrome already launched with --remote-debugging-port, drives
// Page.captureScreenshot over the DevTools Protocol and writes real PNGs to
// ./screenshots/. NO OS cursor/keyboard injection, NO full-screen screencapture
// — this targets the page/tab directly. Dependency-free: Node 24's built-in
// global WebSocket + fetch.
//
// Modes:
//   --once <file>                      capture one frame after --settle ms
//   --tour --expect a,b,c [--max-ms N] capture one frame per `VYBIA_PROOF <name>`
//                                      console marker, saved as screenshots/<name>.png,
//                                      until every expected name is captured (or timeout)
//
// Common: --port 9222 --settle 1400 --url-filter localhost

const args = parseArgs(process.argv.slice(2));
const PORT = Number(args.port ?? 9222);
const SETTLE = Number(args.settle ?? 1400);
const URL_FILTER = args['url-filter'] ?? 'localhost';
const OUT_DIR = args['out-dir'] ?? 'screenshots';

import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      const v = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
      out[k] = v;
    } else out._.push(a);
  }
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function findPageTarget() {
  // Retry — Chrome may still be spinning up / loading the SPA.
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json`);
      const list = await res.json();
      const page = list.find(
        (t) => t.type === 'page' && (t.url || '').includes(URL_FILTER),
      );
      if (page?.webSocketDebuggerUrl) return page;
    } catch (_) {
      /* not up yet */
    }
    await sleep(500);
  }
  throw new Error(`No page target matching "${URL_FILTER}" on port ${PORT}`);
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
      } else if (msg.method) {
        for (const l of this.listeners) l(msg);
      }
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) =>
      this.pending.set(id, { resolve, reject }),
    );
  }
  on(fn) {
    this.listeners.push(fn);
  }
}

async function connect() {
  const page = await findPageTarget();
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });
  const cdp = new Cdp(ws);
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  return { cdp, ws, page };
}

async function shoot(cdp, file) {
  const { data } = await cdp.send('Page.captureScreenshot', { format: 'png' });
  mkdirSync(OUT_DIR, { recursive: true });
  const path = join(OUT_DIR, file.endsWith('.png') ? file : `${file}.png`);
  writeFileSync(path, Buffer.from(data, 'base64'));
  console.log(`  ✓ saved ${path}`);
  return path;
}

function consoleText(params) {
  if (!params?.args) return '';
  return params.args.map((a) => a.value ?? a.description ?? '').join(' ');
}

async function runOnce(file) {
  const { cdp, ws } = await connect();
  console.log(`connected; settling ${SETTLE}ms then capturing ${file}`);
  await sleep(SETTLE);
  await shoot(cdp, file);
  ws.close();
}

async function runTour(expect, maxMs) {
  const { cdp, ws } = await connect();
  const wanted = new Set(expect);
  const claimed = new Set(); // marker seen (capture scheduled)
  const shot = new Set(); // capture written to disk
  console.log(`tour: waiting for markers: ${[...wanted].join(', ')}`);

  let resolveDone;
  const done = new Promise((r) => (resolveDone = r));
  // Serialize only the shoot() calls (so two never race the protocol) WITHOUT
  // serializing the settle delays — each capture fires exactly SETTLE after ITS
  // marker, never lagging behind the previous capture's settle (that lag drifted
  // every frame one phase ahead).
  let shootLock = Promise.resolve();

  cdp.on((msg) => {
    if (msg.method !== 'Runtime.consoleAPICalled') return;
    const text = consoleText(msg.params);
    const m = text.match(/VYBIA_PROOF\s+(\S+)/);
    if (!m) return;
    const name = m[1];
    if (name === 'DONE') {
      resolveDone();
      return;
    }
    if (!wanted.has(name) || claimed.has(name)) return;
    claimed.add(name);
    console.log(`marker ${name} → capturing in ${SETTLE}ms`);
    setTimeout(() => {
      shootLock = shootLock
        .then(async () => {
          await shoot(cdp, name);
          shot.add(name);
          if ([...wanted].every((w) => shot.has(w))) resolveDone();
        })
        .catch((e) => console.error(`shoot ${name} failed:`, e.message));
    }, SETTLE);
  });

  const timeout = sleep(maxMs).then(() => 'timeout');
  const result = await Promise.race([done.then(() => 'done'), timeout]);
  await shootLock; // flush any in-flight capture
  ws.close();
  const missing = [...wanted].filter((w) => !shot.has(w));
  console.log(
    `tour ${result}: captured ${shot.size}/${wanted.size}` +
      (missing.length ? ` — MISSING: ${missing.join(', ')}` : ''),
  );
  if (missing.length) process.exitCode = 2;
}

(async () => {
  if (args.once) {
    await runOnce(typeof args.once === 'string' ? args.once : 'capture.png');
  } else if (args.tour) {
    const expect = String(args.expect ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    await runTour(expect, Number(args['max-ms'] ?? 120000));
  } else {
    console.error('Usage: --once <file> | --tour --expect a,b,c');
    process.exit(1);
  }
})().catch((e) => {
  console.error('CDP capture failed:', e.message);
  process.exit(1);
});
