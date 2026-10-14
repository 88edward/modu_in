// src/db/*.sql 을 번호 순서대로 D1 에 넣는다.
//   pnpm db:seed:local               → 로컬 개발용 D1 (.wrangler/state)
//   pnpm db:seed:remote              → Cloudflare 의 실제 D1
//   pnpm db:seed:local --reset       → 먼저 모든 표를 지우고 다시 넣기 (세션 기록도 지워짐!)
//
// D1 은 SQL 문장 하나가 100KB 를 넘으면 실행되지 않으므로, 긴 INSERT 는 행 단위로 나눠서 넣는다.
// 원본 SQL 파일은 건드리지 않고 .wrangler/seed/ 에 나눈 파일을 만들어 실행한다.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

// 프로젝트 node_modules 의 wrangler 실행 파일 (npm·pnpm 모두 이 위치에 연결됨)
const WRANGLER = path.join(process.cwd(), 'node_modules', 'wrangler', 'bin', 'wrangler.js');
if (!fs.existsSync(WRANGLER)) {
  console.error('wrangler 가 설치되어 있지 않아요. 먼저 pnpm install 을 실행하세요.');
  process.exit(1);
}

const ROOT = process.cwd();
const SQL_DIR = path.join(ROOT, 'src', 'db');
const OUT_DIR = path.join(ROOT, '.wrangler', 'seed');
const DB_BINDING = 'DB'; // wrangler.jsonc 의 d1_databases[].binding
const MAX_STATEMENT = 90 * 1024;

const args = process.argv.slice(2);
const target = args.includes('--remote') ? '--remote' : args.includes('--local') ? '--local' : null;
const reset = args.includes('--reset');
if (!target) {
  console.error('사용법: node scripts/d1-seed.mjs --local | --remote [--reset]');
  process.exit(1);
}

/** 문자열('...')과 주석(--)을 고려해 문장 단위로 나눈다 */
function splitStatements(sql) {
  const out = [];
  let cur = '';
  let inStr = false;
  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    if (inStr) {
      cur += ch;
      if (ch === "'") {
        if (sql[i + 1] === "'") cur += sql[++i];
        else inStr = false;
      }
      continue;
    }
    if (ch === '-' && sql[i + 1] === '-') {
      while (i < sql.length && sql[i] !== '\n') i++;
      cur += '\n';
      continue;
    }
    if (ch === "'") inStr = true;
    if (ch === ';') {
      if (cur.trim()) out.push(cur.trim());
      cur = '';
      continue;
    }
    cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

/** "INSERT ... VALUES (..), (..)" 를 행 묶음으로 나눈다 */
function splitInsert(stmt) {
  const m = stmt.match(/^(INSERT\s+(?:OR\s+\w+\s+)?INTO\s+[\s\S]*?\)\s*VALUES)\s*/i);
  if (!m) return [stmt];
  const head = m[1];
  const rows = [];
  let depth = 0;
  let inStr = false;
  let start = -1;
  for (let i = m[0].length; i < stmt.length; i++) {
    const ch = stmt[i];
    if (inStr) {
      if (ch === "'") {
        if (stmt[i + 1] === "'") i++;
        else inStr = false;
      }
      continue;
    }
    if (ch === "'") inStr = true;
    else if (ch === '(') {
      if (depth === 0) start = i;
      depth++;
    } else if (ch === ')') {
      depth--;
      if (depth === 0) rows.push(stmt.slice(start, i + 1));
    }
  }
  // 크기는 글자 수가 아니라 UTF-8 바이트로 잰다 (한글 1자 = 3바이트)
  const bytes = (s) => Buffer.byteLength(s);
  const chunks = [];
  let batch = [];
  let size = bytes(head);
  for (const r of rows) {
    const n = bytes(r) + 2;
    if (batch.length && size + n > MAX_STATEMENT) {
      chunks.push(`${head}\n${batch.join(',\n')}`);
      batch = [];
      size = bytes(head);
    }
    batch.push(r);
    size += n;
  }
  if (batch.length) chunks.push(`${head}\n${batch.join(',\n')}`);
  return chunks;
}

const files = fs
  .readdirSync(SQL_DIR)
  .filter((f) => /^\d+_.*\.sql$/.test(f))
  .sort((a, b) => parseInt(a) - parseInt(b) || a.localeCompare(b));

fs.rmSync(OUT_DIR, { recursive: true, force: true });
fs.mkdirSync(OUT_DIR, { recursive: true });

const jobs = [];
if (reset) {
  // 시드 파일들의 CREATE TABLE 순서를 거꾸로 지운다 (참조하는 표부터)
  const all = files.map((f) => fs.readFileSync(path.join(SQL_DIR, f), 'utf8')).join('\n');
  const tables = [...all.matchAll(/CREATE TABLE(?: IF NOT EXISTS)?\s+(\w+)/gi)].map((x) => x[1]);
  const drop = [...new Set(tables)].reverse().map((t) => `DROP TABLE IF EXISTS ${t};`);
  const f = path.join(OUT_DIR, '00_reset.sql');
  fs.writeFileSync(f, ['PRAGMA defer_foreign_keys = true;', ...drop].join('\n'));
  jobs.push(f);
}

for (const file of files) {
  const stmts = splitStatements(fs.readFileSync(path.join(SQL_DIR, file), 'utf8'))
    .filter((s) => !/^PRAGMA\s+foreign_keys/i.test(s)) // D1 은 외래키를 기본으로 검사하고, 이 PRAGMA 는 허용하지 않는다
    .flatMap((s) => (Buffer.byteLength(s) > MAX_STATEMENT ? splitInsert(s) : [s]));
  const too = stmts.filter((s) => Buffer.byteLength(s) > 100 * 1024);
  if (too.length) {
    console.error(`${file}: 100KB 를 넘는 문장을 나누지 못했어요 (${too.length}개)`);
    process.exit(1);
  }
  const out = path.join(OUT_DIR, file);
  fs.writeFileSync(out, stmts.map((s) => `${s};`).join('\n\n'));
  jobs.push(out);
}

console.log(`D1 ${target === '--remote' ? '원격(Cloudflare)' : '로컬'}에 시드를 넣습니다${reset ? ' (모든 표를 지운 뒤)' : ''}…`);
for (const f of jobs) {
  console.log(`  · ${path.basename(f)}`);
  // 프로젝트에 설치된 wrangler 를 Node 로 바로 실행 (npm·pnpm 어느 쪽으로 실행해도 같은 버전을 씀)
  const r = spawnSync(process.execPath, [WRANGLER, 'd1', 'execute', DB_BINDING, target, `--file=${path.relative(ROOT, f)}`, '--yes'], {
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  if (r.status !== 0) {
    console.error(`\n실패: ${path.basename(f)}${reset ? '' : '\n이미 표가 있으면 --reset 을 붙여 다시 실행하세요 (세션 기록도 지워져요).'}`);
    process.exit(r.status ?? 1);
  }
}
console.log('완료!');
