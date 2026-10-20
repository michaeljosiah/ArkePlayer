// Checks over design/Arke Player.dc.html, the Arke Player's design master. Runs in CI.
//
//   node design/check.mjs            static checks
//   node design/check.mjs --record   add new turns to turns.json (never removes one, never lowers a count)
//   node design/check.mjs --render   also render through the dc runtime in headless Chrome and prove
//                                    every card painted in Geist (needs Chrome and network for React)
//
// Static: every frame sets type through the tokens (a raw `font-size: 11px` fails), no card is only a
// bitmap (a turn is approved from HTML), ids are unique, every `#anchor` resolves, every picture a frame
// names exists, and no turn drops out or loses a binding rule (the ledger is turns.json). This is the
// gate ArkeStudio's check-master.mjs ran over this file while it lived there.
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const MASTER = join(here, 'Arke Player.dc.html');
const LEDGER = join(here, 'turns.json');
const RAW_SIZE = /\bfont(?:-size)?\s*:\s*(?:[0-9]{3}\s+)?[0-9]+(?:\.[0-9]+)?px/g;

const failures = [];
const fail = (message) => failures.push(message);
const html = readFileSync(MASTER, 'utf8');

const starts = [...html.matchAll(/<section class="dv-turn" id="(p\d+)"/g)];
if (!starts.length) fail('no p-numbered turns found');
const turns = starts.map((m, i) => ({ id: m[1], body: html.slice(m.index, i + 1 < starts.length ? starts[i + 1].index : undefined) }));

for (const { id, body } of turns) {
  const hits = body.match(RAW_SIZE) ?? [];
  if (hits.length) fail(`${id}: ${hits.length} raw font size(s) — frames set type through var(--text-*) / var(--type-*) only: ${[...new Set(hits)].slice(0, 6).join(', ')}`);
  for (const card of body.split(/<div class="dv-card"[^>]*>/).slice(1)) {
    if (/^\s*<img\b[^>]*>\s*<\/div>/.test(card.slice(0, 600).replace(/\s+/g, ' '))) fail(`${id}: a card that is only an <img>`);
  }
}

const ids = new Map();
for (const m of html.matchAll(/\bid="([^"]+)"/g)) ids.set(m[1], (ids.get(m[1]) ?? 0) + 1);
for (const [id, n] of ids) if (n > 1) fail(`id "${id}" appears ${n} times`);
const missing = [...new Set([...html.matchAll(/href="#([^"]+)"/g)].map((m) => m[1]).filter((id) => !ids.has(id)))];
if (missing.length) fail(`anchors with no target: ${missing.slice(0, 12).join(', ')}`);
for (const m of html.matchAll(/src="(assets\/[^"]+)"/g)) if (!existsSync(join(here, m[1]))) fail(`missing picture ${m[1]}`);

const ruleCount = (body) => (body.match(/class="dv-rule"/g) ?? []).length;
const counts = new Map(turns.map(({ id, body }) => [id, ruleCount(body)]));
const ledger = existsSync(LEDGER) ? JSON.parse(readFileSync(LEDGER, 'utf8')) : { turns: {} };
if (process.argv.includes('--record')) {
  const next = { ...ledger.turns };
  for (const [id, rules] of counts) next[id] = Math.max(rules, next[id] ?? 0);
  const sorted = Object.fromEntries(Object.entries(next).sort(([a], [b]) => Number(a.slice(1)) - Number(b.slice(1))));
  writeFileSync(LEDGER, JSON.stringify({ note: 'Every turn the Arke Player master has held, with its count of dv-rule paragraphs. design/check.mjs fails if a turn drops out or its rules fall; add a new turn with node design/check.mjs --record.', turns: sorted }, null, 2) + '\n');
  console.log(`turns.json: ${Object.keys(sorted).length} turns recorded`);
} else {
  for (const [id, rules] of Object.entries(ledger.turns)) {
    if (!counts.has(id)) fail(`${id} dropped — turns.json holds it with ${rules} rule(s); restore it from the commit that last had it`);
    else if (counts.get(id) < rules) fail(`${id} lost ${rules - counts.get(id)} binding rule(s)`);
  }
  const unrecorded = [...counts.keys()].filter((id) => !(id in ledger.turns));
  if (unrecorded.length) fail(`turn(s) not in turns.json: ${unrecorded.join(', ')} — run node design/check.mjs --record`);
}

if (process.argv.includes('--render')) {
  try {
    const r = await render(MASTER);
    console.log(`rendered ${r.cards} cards · Geist faces loaded ${r.loaded}`);
    if (r.cards < turns.length) fail(`only ${r.cards} cards rendered`);
    if (!r.loaded) fail('no Geist face loaded');
  } catch (error) {
    fail(String(error?.message ?? error));
  }
}

if (failures.length) {
  console.error(`Arke Player design: ${failures.length} problem(s)`);
  for (const f of failures) console.error(' - ' + f);
  process.exit(1);
}
console.log(`Arke Player design: ${turns.length} turns, ${[...counts.values()].reduce((a, b) => a + b, 0)} rules, anchors resolve`);

/** Render the master through its dc runtime in headless Chrome and count cards and Geist faces. */
async function render(file) {
  const chrome = process.env.CHROME ?? ['C:/Program Files/Google/Chrome/Application/chrome.exe', '/usr/bin/google-chrome', '/usr/bin/chromium'].find((p) => existsSync(p));
  if (!chrome) throw new Error('--render needs Chrome; set CHROME');
  const port = 9400 + Math.floor(Math.random() * 400);
  const profile = mkdtempSync(join(tmpdir(), 'ap-check-'));
  const proc = spawn(chrome, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--no-first-run', '--disable-gpu', 'about:blank'], { stdio: 'ignore' });
  try {
    let target = null;
    for (let i = 0; i < 50 && !target; i++) {
      try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === 'page')?.webSocketDebuggerUrl ?? null; } catch { /* not up yet */ }
      if (!target) await new Promise((r) => setTimeout(r, 300));
    }
    if (!target) throw new Error('Chrome did not expose a debugging target');
    const ws = new WebSocket(target);
    await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('websocket failed')); });
    let seq = 0;
    const pending = new Map();
    ws.onmessage = (e) => { const m = JSON.parse(String(e.data)); if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); } };
    const send = (method, params = {}) => new Promise((res) => { const id = ++seq; pending.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
    const evaluate = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }))?.result?.value;
    await send('Page.enable');
    await send('Page.navigate', { url: pathToFileURL(file).href });
    let cards = 0;
    for (let i = 0; i < 60 && cards < 30; i++) {
      cards = (await evaluate("document.querySelectorAll('[data-screen-label]').length")) ?? 0;
      if (cards < 30) await new Promise((r) => setTimeout(r, 1000));
    }
    await evaluate('document.fonts.ready.then(() => true)');
    const loaded = (await evaluate("[...document.fonts].filter(f => /^Geist/.test(f.family) && f.status === 'loaded').length")) ?? 0;
    ws.close();
    return { cards, loaded };
  } finally {
    try { proc.kill(); } catch {}
    try { rmSync(profile, { recursive: true, force: true }); } catch {}
  }
}
