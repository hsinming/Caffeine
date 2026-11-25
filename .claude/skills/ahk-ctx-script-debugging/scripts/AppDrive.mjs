// Operates an app started by `Invoke-AhkProbe.ps1 -Mode Drive`, over CDP. Needs Node 22+ and no package.
//   node AppDrive.mjs <evidenceDir> doctor | eval <js> | click <css> | screenshot <name> | stop   [--page <part of the URL>]
// Each call is one step: it prints one JSON object, appends it to steps.jsonl, and exits 1 when not ok.
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const pageFlag = args.indexOf('--page');
const pageFilter = pageFlag < 0 ? '' : args.splice(pageFlag, 2)[1] ?? '';
const [dir, command, arg] = args;
const file = name => path.join(dir, name);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const readJson = name => JSON.parse(fs.readFileSync(file(name), 'utf8'));

async function until(ms, what, fn) {
  const end = Date.now() + ms;
  for (;;) {
    let why;
    try { const v = await fn(); if (v) return v; } catch (e) { if (e.fatal) throw e; why = e.message; }
    if (Date.now() > end) throw new Error(why ? `${what}: ${why}` : what);
    await sleep(200);
  }
}
function session() {
  if (fs.existsSync(file('result.json')))
    throw Object.assign(new Error(`the drive has ended: ${readJson('result.json').verdict}`), { fatal: true });
  const s = readJson('session.json');
  try { process.kill(s.pid, 0); } catch { throw new Error('the app is not running'); }
  return s;
}
async function findPage() {
  const { port } = session();
  const list = await (await fetch(`http://127.0.0.1:${port}/json`, { signal: AbortSignal.timeout(3000) })).json();
  const pages = list.filter(t => t.type === 'page' && t.url !== 'about:blank' && t.url.includes(pageFilter));
  if (pages.length !== 1) throw new Error(`${pages.length} pages match, want 1 (--page narrows): ${pages.map(p => p.url).join(' ')}`);
  return pages[0];
}
async function connect(waitMs = 5000) {
  const page = await until(waitMs, 'no page', findPage);
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = () => no(new Error('CDP connection failed')); });
  const waiting = new Map();
  let id = 0;
  ws.onmessage = e => { const m = JSON.parse(e.data); waiting.get(m.id)?.(m); };
  const send = (method, params = {}) => new Promise((ok, no) => {
    const timer = setTimeout(() => no(new Error(`${method}: no answer in 15 s`)), 15000);
    waiting.set(++id, m => { clearTimeout(timer); m.error ? no(new Error(`${method}: ${m.error.message}`)) : ok(m.result); });
    ws.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    const x = r.exceptionDetails;
    if (x) throw new Error(x.exception?.description ?? JSON.stringify(x.exception?.value) ?? x.text);
    return r.result.value ?? r.result.unserializableValue ?? null;
  };
  return { page, send, evaluate };
}

const commands = {
  async doctor() {
    const s = await until(30000, 'session.json is missing; is the runner up?', session);
    const { page, evaluate } = await connect(30000);
    await until(15000, 'the page did not finish loading', () => evaluate('document.readyState === "complete"'));
    // The proof that the redirect took: without it the app uses the user's real WebView2 folder.
    const profile = fs.globSync(['*/EBWebView', '*/*/EBWebView'], { cwd: s.localAppData })[0];
    if (!profile) {
      fs.writeFileSync(file('stop'), '');
      throw new Error(`no EBWebView folder under the redirected LOCALAPPDATA ${s.localAppData}: not isolated, drive stopped`);
    }
    return { url: page.url, title: await evaluate('document.title'), profile };
  },
  async eval() { return (await connect()).evaluate(arg); },
  async click() {
    const { send, evaluate } = await connect();
    const { x, y } = await until(5000, `cannot click ${arg}`, () => evaluate(`(async () => {
      const el = document.querySelector(${JSON.stringify(arg)});
      if (!el) throw new Error('no such element');
      if (el.matches(':disabled')) throw new Error('disabled');
      el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' });
      const spot = () => { const r = el.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; };
      const a = spot(); await new Promise(r => setTimeout(r, 100)); const b = spot();
      if (a.x !== b.x || a.y !== b.y) throw new Error('still moving');
      const hit = document.elementFromPoint(b.x, b.y);
      if (!el.contains(hit)) throw new Error('hidden or covered by ' + (hit?.outerHTML.slice(0, 80) ?? 'nothing'));
      return b;
    })()`));
    const mouse = (type, buttons) => send('Input.dispatchMouseEvent', { type, x, y, button: 'left', buttons, clickCount: 1 });
    await mouse('mousePressed', 1);
    await mouse('mouseReleased', 0);
    return { x, y };
  },
  async screenshot() {
    if (!/^[\w-]+$/.test(arg ?? '')) throw new Error('name: letters, digits, _ and - only');
    const { send } = await connect();
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(file(`${arg}.png`), Buffer.from(data, 'base64'));
    return `${arg}.png`;
  },
  async stop() {
    session();
    fs.writeFileSync(file('stop'), '');
    step.value = await until(40000, 'the runner did not end', () => fs.existsSync(file('result.json')) && readJson('result.json'));
    if (step.value.verdict !== 'PASS') throw new Error(`verdict ${step.value.verdict}`);
    return step.value;
  },
};

if (!dir || !command) {
  console.error('usage: node AppDrive.mjs <evidenceDir> doctor|eval|click|screenshot|stop [argument] [--page <part of the URL>]');
  process.exit(1);
}
const started = Date.now();
const step = { time: new Date().toISOString(), command, arg, page: pageFilter || undefined, ok: true };
try {
  if (!Object.hasOwn(commands, command)) throw new Error('unknown command');
  step.value = await commands[command]();
} catch (e) {
  step.ok = false;
  step.error = e.message;
}
step.ms = Date.now() - started;
if (fs.existsSync(dir)) fs.appendFileSync(file('steps.jsonl'), JSON.stringify(step) + '\n');
console.log(JSON.stringify(step));
process.exit(step.ok ? 0 : 1);
