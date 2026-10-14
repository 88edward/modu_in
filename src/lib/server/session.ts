// 세션 저장 (D1): chat_sessions / session_uploads / extracted_facts / session_steps (+ 판정 결과 반영)
import { all, batch, first, run } from './d1';
import { cat } from './catalog';
import type { FactKey } from './gemini';
import { FACT_KEYS } from './gemini';

export interface Step {
  key: string;
  value: string;
  system: boolean;
}

export interface ResolvedFact {
  key: string;
  value: string;
  evidence: string | null;
  source: string | null; // 업로드 종류/파일명
  confidence: number;
  confirmed: boolean;
  conflict: string[];
}

export type UploadKind = 'product_name' | 'photo' | 'manual' | 'certificate';

export interface NewFact {
  key: string;
  value: string;
  evidence?: string | null;
  confidence: number;
  method: 'ai' | 'regex';
  model?: string | null;
  status?: 'pending' | 'confirmed' | 'rejected';
}

const FACT_SQL = `INSERT INTO extracted_facts (session_id, variable, value, upload_id, method, model, confidence, evidence, status)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;
const factParams = (sessionId: string, f: NewFact, uploadId: number | null) => [
  sessionId,
  f.key,
  f.value,
  uploadId,
  f.method,
  f.model ?? null,
  f.confidence,
  f.evidence ?? null,
  f.status ?? 'pending',
];

export async function createSession(): Promise<string> {
  const id = crypto.randomUUID();
  await run('INSERT INTO chat_sessions (id) VALUES (?)', id);
  return id;
}

export async function sessionExists(id: string): Promise<boolean> {
  return Boolean(await first('SELECT 1 AS x FROM chat_sessions WHERE id = ?', id));
}

/** 업로드 1건 + 그 자료에서 뽑은 값들을 한 번에 저장. 원본 파일은 저장하지 않고 파일명만 기록 */
export async function addUploadWithFacts(sessionId: string, kind: UploadKind, fileName: string | null, text: string, facts: NewFact[] = []) {
  const up = await first<{ id: number }>(
    'INSERT INTO session_uploads (session_id, kind, r2_key, text_value) VALUES (?, ?, ?, ?) RETURNING id',
    sessionId,
    kind,
    fileName,
    text,
  );
  const uploadId = up?.id ?? null;
  await batch(facts.map((f) => ({ sql: FACT_SQL, params: factParams(sessionId, f, uploadId) })));
}

export async function getUploads(sessionId: string) {
  return all<{ id: number; kind: string; r2_key: string | null; text_value: string | null }>(
    'SELECT id, kind, r2_key, text_value FROM session_uploads WHERE session_id = ? ORDER BY id',
    sessionId,
  );
}

/** 사용자가 직접 입력한 제품명 */
export function typedNameOf(uploads: { kind: string; text_value: string | null }[]): string {
  return uploads.filter((u) => u.kind === 'product_name').at(-1)?.text_value ?? '';
}

/**
 * 변수별 최종 값 결정
 *  1) 사용자가 확인/수정한 값(confirmed/rejected)이 있으면 그것
 *  2) 없으면 자료 우선순위(source_priority: 인증서 > 설명서 > 사진) → 확신도 순
 *  자료끼리 값이 다르면 conflict 에 다른 값들을 담는다.
 */
export async function resolveFacts(sessionId: string): Promise<Map<string, ResolvedFact>> {
  const rows = await all<{
    id: number;
    variable: string;
    value: string;
    evidence: string | null;
    confidence: number | null;
    status: string;
    kind: string | null;
    file: string | null;
  }>(
    `SELECT f.id, f.variable, f.value, f.evidence, f.confidence, f.status, u.kind, u.r2_key AS file
       FROM extracted_facts f
       LEFT JOIN session_uploads u ON u.id = f.upload_id
      WHERE f.session_id = ?
      ORDER BY f.id`,
    sessionId,
  );
  const priority = cat().sourcePriority;

  const out = new Map<string, ResolvedFact>();
  const byVar = new Map<string, typeof rows>();
  for (const r of rows) byVar.set(r.variable, [...(byVar.get(r.variable) ?? []), r]);

  for (const [key, list] of byVar) {
    const user = list.filter((r) => r.status === 'confirmed' || r.status === 'rejected').at(-1);
    const prio = (r: (typeof rows)[number]) => (r.kind ? (priority.get(r.kind) ?? 9) : 9);
    const auto = list
      .filter((r) => r.status === 'pending' || r.status === 'conflict')
      .sort((a, b) => prio(a) - prio(b) || (b.confidence ?? 0) - (a.confidence ?? 0));
    const best = auto[0];
    const norm = (s: string) => s.replace(/\s+/g, '').toLowerCase();
    const conflict = best ? [...new Set(auto.filter((r) => norm(r.value) !== norm(best.value)).map((r) => r.value))] : [];

    if (user) {
      if (user.status === 'rejected' || user.value.trim() === '') continue;
      out.set(key, { key, value: user.value, evidence: user.evidence, source: '직접 확인', confidence: 1, confirmed: true, conflict: [] });
    } else if (best) {
      out.set(key, {
        key,
        value: best.value,
        evidence: best.evidence,
        source: best.file ?? best.kind,
        confidence: best.confidence ?? 0.5,
        confirmed: false,
        conflict,
      });
    }
  }
  return out;
}

/** 자료 확인 화면에서 사용자가 고친 값 저장 (빈 값 = 해당 없음으로 거절) */
export async function saveUserFacts(sessionId: string, values: Record<string, string>) {
  const current = await resolveFacts(sessionId);
  const stmts: { sql: string; params: unknown[] }[] = [];
  for (const [key, raw] of Object.entries(values)) {
    if (!(key in FACT_KEYS)) continue;
    const value = String(raw ?? '').trim().slice(0, 500);
    const prev = current.get(key);
    if (prev && prev.value === value && prev.conflict.length === 0) continue; // 그대로면 기록 안 함
    if (!prev && value === '') continue;
    const f: NewFact = {
      key: key as FactKey,
      value,
      evidence: '사용자가 직접 확인·수정',
      confidence: 1,
      method: 'ai',
      model: 'user',
      status: value === '' ? 'rejected' : 'confirmed',
    };
    stmts.push({ sql: FACT_SQL, params: factParams(sessionId, f, null) });
  }
  await batch(stmts);
}

// ---------------------------------------------------------------- steps

export async function getSteps(sessionId: string): Promise<Step[]> {
  const rows = await all<{ step_key: string; value: string; is_system: number }>(
    'SELECT step_key, value, is_system FROM session_steps WHERE session_id = ? ORDER BY seq',
    sessionId,
  );
  return rows.map((r) => ({ key: r.step_key, value: r.value, system: r.is_system === 1 }));
}

export async function pushStep(sessionId: string, key: string, value: string, system = false) {
  // 다음 순번을 같은 문장 안에서 계산 (동시 요청에도 순번이 꼬이지 않게)
  await run(
    `INSERT INTO session_steps (session_id, seq, step_key, value, is_system)
     VALUES (?, (SELECT COALESCE(MAX(seq), 0) + 1 FROM session_steps WHERE session_id = ?), ?, ?, ?)`,
    sessionId,
    sessionId,
    key,
    value,
    system ? 1 : 0,
  );
}

/** '이전': 마지막 사용자 답 1개와 그 뒤의 시스템 기록을 지운다. 지운 게 없으면 false */
export async function popStep(sessionId: string): Promise<boolean> {
  const last = await first<{ seq: number }>('SELECT MAX(seq) AS seq FROM session_steps WHERE session_id = ? AND is_system = 0', sessionId);
  if (!last?.seq) return false;
  await run('DELETE FROM session_steps WHERE session_id = ? AND seq >= ?', sessionId, last.seq);
  return true;
}

/**
 * 위쪽 기록 선에서 index 번째 답(시스템 기록 제외, 0부터)으로 돌아가기:
 * 그 답과 그 뒤의 모든 기록을 지운다 → 그 질문이 다시 나온다. 범위를 벗어나면 false
 */
export async function rewindTo(sessionId: string, index: number): Promise<boolean> {
  if (!Number.isInteger(index) || index < 0) return false;
  const row = await first<{ seq: number }>(
    'SELECT seq FROM session_steps WHERE session_id = ? AND is_system = 0 ORDER BY seq LIMIT 1 OFFSET ?',
    sessionId,
    index,
  );
  if (!row) return false;
  await run('DELETE FROM session_steps WHERE session_id = ? AND seq >= ?', sessionId, row.seq);
  return true;
}

// ---------------------------------------------------------------- 판정 결과 반영 (조회·감사용)

export async function saveOutcome(
  sessionId: string,
  o: {
    vars: Record<string, unknown>;
    status: 'in_progress' | 'done' | 'escalated' | 'waiting' | 'out_of_scope';
    items: { itemId: number; role: 'primary' | 'parallel' | 'component'; addedBy: string }[];
    answers: { nodeId: number; value: string; auto: boolean }[];
  },
) {
  const stmts: { sql: string; params: unknown[] }[] = [
    { sql: 'UPDATE chat_sessions SET vars = ?, status = ? WHERE id = ?', params: [JSON.stringify(o.vars), o.status, sessionId] },
    { sql: 'DELETE FROM session_items WHERE session_id = ?', params: [sessionId] },
    { sql: 'DELETE FROM chat_answers WHERE session_id = ?', params: [sessionId] },
  ];
  const seen = new Set<number>();
  for (const it of o.items) {
    if (seen.has(it.itemId)) continue;
    seen.add(it.itemId);
    stmts.push({ sql: 'INSERT INTO session_items (session_id, item_id, role, added_by) VALUES (?, ?, ?, ?)', params: [sessionId, it.itemId, it.role, it.addedBy] });
  }
  for (const a of o.answers) {
    stmts.push({ sql: 'INSERT INTO chat_answers (session_id, node_id, value, auto_filled) VALUES (?, ?, ?, ?)', params: [sessionId, a.nodeId, a.value, a.auto ? 1 : 0] });
  }
  await batch(stmts);
}
