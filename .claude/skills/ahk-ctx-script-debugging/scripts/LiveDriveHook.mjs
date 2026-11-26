// PreToolUse hook of the Live Drive (ahk-home-repo ADR 0002, decision 2). Matcher: Bash|PowerShell.
// A command that runs Invoke-LiveDrive.ps1 gets "ask", naming its system and feature, and leaves the single-use
// marker that Invoke-LiveDrive.ps1 needs: %LOCALAPPDATA%\AppDrive\live-marker.json. Any other command passes untouched.
// A command that chains another one, or names no system or feature, is denied: one approval covers one run.
import fs from 'node:fs';
import path from 'node:path';

const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const command = String(input.tool_input?.command ?? '');
const marker = path.join(process.env.LOCALAPPDATA, 'AppDrive', 'live-marker.json');
if (!/Invoke-LiveDrive\.ps1/i.test(command)) process.exit(0);
// Every command that names it starts from no marker; only an ask below leaves one. So a run written another way
// (a dot-source, -Command) never uses a marker that a declined run left.
fs.rmSync(marker, { force: true });
// Asked only for a command that runs it: -File, &, or first.
if (!/(^\s*|-File\s+|&\s*)(["'][^"']*|[^"'\s]*)Invoke-LiveDrive\.ps1/i.test(command)) process.exit(0);

const answer = (permissionDecision, permissionDecisionReason) => {
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision, permissionDecisionReason } }));
  process.exit(0);
};
const arg = name => command.match(new RegExp(`-${name}\\s+['"]?([A-Za-z0-9_-]+)['"]?(?=\\s|$)`, 'i'))?.[1];
const system = arg('System'), feature = arg('Feature');
if (command.match(/Invoke-LiveDrive\.ps1/gi).length > 1 || /[;|\r\n`]|&&|\$\(|\b(Start-Job|Start-Process)\b/i.test(command))
  answer('deny', 'Live Drive: run Invoke-LiveDrive.ps1 alone, one system and one feature per command.');
if (!system || !feature) answer('deny', 'Live Drive: name -System and -Feature.');

fs.mkdirSync(path.dirname(marker), { recursive: true });
fs.writeFileSync(marker, JSON.stringify({ system, feature, created: Date.now() }));
answer('ask', `Live Drive on the real ${system}, feature "${feature}". Allow this one run?`);
