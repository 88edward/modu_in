// 표시사항 생성 흐름 API
//  POST multipart  { productName, files[] }              → 세션 시작 + 문서 추출
//  POST json       { action: 'state',  sessionId }       → 현재 화면
//                  { action: 'answer', sessionId, key, value, facts? } → 답 기록 후 다음 화면
//                  { action: 'back',   sessionId }       → 마지막 답 취소
//                  { action: 'goto',   sessionId, index } → index 번째 답으로 돌아가기 (그 뒤 답 취소)
import type { APIRoute } from 'astro';
import { runEngine } from '../../lib/server/engine';
import { extractFromFile, geminiModel, hasGeminiKey, suggestItems, GeminiError } from '../../lib/server/gemini';
import { catalogue } from '../../lib/server/match';
import { loadCatalog } from '../../lib/server/catalog';
import {
  addUploadWithFacts,
  createSession,
  getSteps,
  getUploads,
  typedNameOf,
  popStep,
  pushStep,
  rewindTo,
  resolveFacts,
  saveOutcome,
  saveUserFacts,
  sessionExists,
} from '../../lib/server/session';
import type { FlowReply, FlowResponse, Screen } from '../../lib/flow-types';

export const prerender = false;

const MAX_FILES = 8;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_TOTAL_BYTES = 18 * 1024 * 1024; // Gemini 인라인 요청 한도(20MB) 안쪽
const MIME_BY_EXT: Record<string, string> = {
  pdf: 'application/pdf',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
  heic: 'image/heic',
  heif: 'image/heif',
  txt: 'text/plain',
};
const KIND_LABEL: Record<string, string> = { certificate: '인증서·시험성적서', manual: '설명서·사양서', photo: '사진' };

const json = (body: FlowReply, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });

/**
 * 엔진을 돌려 현재 화면 계산. AI 추천이 필요하면 한 번 부르고 결과를 기록한 뒤 다시 계산한다.
 * save=false 면 판정 결과를 DB에 반영하지 않는다(답 검증용으로 현재 화면만 볼 때).
 */
async function current(sessionId: string, notice?: string | null, save = true): Promise<FlowResponse> {
  for (let i = 0; i < 3; i++) {
    const [uploads, facts, steps] = await Promise.all([getUploads(sessionId), resolveFacts(sessionId), getSteps(sessionId)]);
    const result = runEngine({
      typedName: typedNameOf(uploads),
      facts,
      docs: uploads.filter((u) => u.kind !== 'product_name').map((u) => ({ name: u.r2_key ?? '(파일)', kind: KIND_LABEL[u.kind] ?? u.kind, chars: u.text_value?.length ?? 0 })),
      steps,
      canUseAi: hasGeminiKey(),
    });
    if (result.kind === 'screen') {
      if (save) await saveOutcome(sessionId, result.outcome);
      return { sessionId, screen: result.screen, progress: result.progress, notice, ...result.extras };
    }
    let suggested: { code: string; reason: string }[] = [];
    try {
      suggested = await suggestItems(result.description, catalogue());
    } catch (e) {
      console.error('[flow] AI 품목 추천 실패:', e);
      notice = 'AI 품목 추천에 실패해서 규칙 검색 결과만 보여드려요.';
    }
    await pushStep(sessionId, result.stepKey, JSON.stringify(suggested), true);
  }
  throw new Error('판정 엔진이 화면을 만들지 못했습니다');
}

/** 지금 화면에서 받을 수 있는 답의 key */
function expectedKeys(screen: Screen): string[] {
  switch (screen.type) {
    case 'facts':
      return ['facts_ok'];
    case 'question':
    case 'wait':
      return [screen.stepKey];
    case 'no_match':
      return ['search', 'pick'];
    case 'source_check':
      return ['source_ack'];
    case 'rules':
      return ['rules_ack'];
    case 'fill':
      return [screen.stepKey];
    default:
      return [];
  }
}

/** 질문 화면의 답이 선택지·형식에 맞는지 */
function validateAnswer(screen: Screen, key: string, value: string): string | null {
  if (key === 'pick' && screen.type === 'no_match') return value === 'none' ? null : '잘못된 선택이에요.';
  // 빈 칸 채우기: 빈 값('나중에 채우기')도 허용
  if (screen.type === 'fill') return value.length > 300 ? '300자 안으로 적어 주세요.' : null;
  if (screen.type !== 'question') return null;
  const allowed = new Set(screen.options.map((o) => o.value));
  if (screen.input === 'single_choice') return allowed.has(value) ? null : '보기 중에서 골라 주세요.';
  if (screen.input === 'multi_choice') {
    try {
      const arr = JSON.parse(value);
      return Array.isArray(arr) && arr.every((v) => allowed.has(String(v))) ? null : '보기 중에서 골라 주세요.';
    } catch {
      return '보기 중에서 골라 주세요.';
    }
  }
  if (screen.input === 'number') return value !== '' && Number.isFinite(Number(value)) && Number(value) >= 0 ? null : '숫자로 적어 주세요.';
  return value.trim() ? null : '내용을 적어 주세요.';
}

/**
 * 확장자만 맞고 내용은 다른 파일 거르기 (예: Mac 이 만드는 "._파일명.pdf" 숨김 파일).
 * 이런 파일을 Gemini 에 보내면 "invalid argument" 로만 실패해서 원인을 알기 어렵다.
 */
async function notRealFile(f: File): Promise<string | null> {
  if (f.name.startsWith('._')) {
    return `'${f.name}'은(는) Mac에서 자동으로 생기는 숨김 파일이에요. 앞에 '._'가 없는 원래 파일을 올려 주세요.`;
  }
  const head = new Uint8Array(await f.slice(0, 12).arrayBuffer());
  const ascii = String.fromCharCode(...head);
  const ext = f.name.split('.').pop()?.toLowerCase() ?? '';
  const ok =
    ext === 'pdf' ? ascii.startsWith('%PDF') :
    ext === 'png' ? head[0] === 0x89 && ascii.slice(1, 4) === 'PNG' :
    ext === 'jpg' || ext === 'jpeg' ? head[0] === 0xff && head[1] === 0xd8 :
    ext === 'webp' ? ascii.startsWith('RIFF') && ascii.slice(8, 12) === 'WEBP' :
    true; // heic·txt 는 형식이 다양해 검사하지 않음
  return ok ? null : `'${f.name}'은(는) 이름은 .${ext}지만 실제 ${ext.toUpperCase()} 파일이 아니에요. 파일을 다시 저장해서 올려 주세요.`;
}

async function start(request: Request) {
  const form = await request.formData();
  const productName = String(form.get('productName') ?? '').trim().slice(0, 100);
  const files = form.getAll('files').filter((f): f is File => f instanceof File && f.size > 0);

  if (!productName && !files.length) return json({ error: '제품 이름을 적거나 자료를 하나 이상 올려 주세요.' }, 400);
  if (files.length > MAX_FILES) return json({ error: `자료는 최대 ${MAX_FILES}개까지 올릴 수 있어요.` }, 400);
  let total = 0;
  for (const f of files) {
    const ext = f.name.split('.').pop()?.toLowerCase() ?? '';
    if (!MIME_BY_EXT[ext]) return json({ error: `'${f.name}'은(는) 읽을 수 없는 형식이에요. PDF·사진(JPG/PNG/WEBP/HEIC)·TXT로 올려 주세요. (HWP·DOCX는 PDF로 저장해서 올려 주세요)` }, 400);
    if (f.size > MAX_FILE_BYTES) return json({ error: `'${f.name}'이(가) 10MB를 넘어요.` }, 400);
    total += f.size;
  }
  if (total > MAX_TOTAL_BYTES) return json({ error: '자료 전체 용량이 18MB를 넘어요. 나눠서 줄여 주세요.' }, 400);
  for (const f of files) {
    const bad = await notRealFile(f);
    if (bad) return json({ error: bad }, 400);
  }
  if (files.length && !hasGeminiKey()) {
    return json({ error: '문서 추출용 GEMINI_API_KEY가 서버에 설정되지 않았어요. (로컬: .dev.vars / 배포: wrangler secret put GEMINI_API_KEY) — 지금은 제품 이름만으로 진행할 수 있어요.' }, 400);
  }

  const sessionId = await createSession();
  if (productName) await addUploadWithFacts(sessionId, 'product_name', null, productName);

  // 파일마다 따로 읽어야 자료 우선순위(인증서 > 설명서 > 사진)로 값을 고를 수 있다
  const failed: string[] = [];
  const results = await Promise.all(
    files.map(async (f) => {
      const ext = f.name.split('.').pop()!.toLowerCase();
      try {
        const data = new Uint8Array(await f.arrayBuffer());
        return { file: f, out: await extractFromFile({ name: f.name, mime: MIME_BY_EXT[ext], data }) };
      } catch (e) {
        console.error(`[flow] 추출 실패 ${f.name}:`, e);
        failed.push(`${f.name}${e instanceof GeminiError ? ` (${e.message})` : ''}`);
        return null;
      }
    }),
  );
  for (const r of results) {
    if (!r) continue;
    await addUploadWithFacts(
      sessionId,
      r.out.docType,
      r.file.name,
      r.out.text,
      r.out.facts.map((fact) => ({ ...fact, method: 'ai' as const, model: geminiModel() })),
    );
    // 인증서 장별 목록은 판정 기록(session_steps)에 시스템 기록으로 남긴다 → 여러 장이면 엔진이 모델을 묻는다
    if (r.out.certificates.length) {
      await pushStep(sessionId, `certs:${r.file.name}`, JSON.stringify(r.out.certificates), true);
    }
  }
  if (files.length && failed.length === files.length && !productName) {
    return json({ error: `자료를 읽지 못했어요: ${failed.join(', ')}` }, 502);
  }
  return json(await current(sessionId, failed.length ? `읽지 못한 자료가 있어요: ${failed.join(', ')}` : null));
}

export const POST: APIRoute = async ({ request }) => {
  try {
    await loadCatalog(); // 기준 데이터 (Worker 인스턴스마다 5분 캐시)
    if ((request.headers.get('content-type') ?? '').includes('multipart/form-data')) return await start(request);

    const body = (await request.json().catch(() => null)) as {
      action?: string;
      sessionId?: string;
      key?: string;
      value?: unknown;
      index?: unknown;
      facts?: Record<string, string>;
    } | null;
    const sessionId = String(body?.sessionId ?? '');
    if (!sessionId || !(await sessionExists(sessionId))) return json({ restart: true });

    if (body?.action === 'state') return json(await current(sessionId));

    if (body?.action === 'back') {
      if (!(await popStep(sessionId))) return json({ restart: true });
      return json(await current(sessionId));
    }

    if (body?.action === 'goto') {
      if (!(await rewindTo(sessionId, Number(body.index)))) return json(await current(sessionId));
      return json(await current(sessionId));
    }

    if (body?.action === 'answer') {
      const key = String(body.key ?? '');
      const value = typeof body.value === 'string' ? body.value : JSON.stringify(body.value ?? '');
      if (!key || value.length > 2000) return json({ error: '잘못된 요청이에요.' }, 400);

      const now = await current(sessionId, null, false);
      if (!expectedKeys(now.screen).includes(key)) return json(now); // 이미 지나간 화면의 중복 제출 → 현재 화면 그대로
      if (key === 'search' && !value.trim()) return json({ error: '찾을 이름을 적어 주세요.' }, 400);
      const invalid = validateAnswer(now.screen, key, value);
      if (invalid) return json({ error: invalid }, 400);
      if (key === 'facts_ok' && body.facts && typeof body.facts === 'object') await saveUserFacts(sessionId, body.facts);
      await pushStep(sessionId, key, value.trim());
      return json(await current(sessionId));
    }

    return json({ error: '알 수 없는 요청이에요.' }, 400);
  } catch (e) {
    console.error('[flow] 오류:', e);
    return json({ error: e instanceof GeminiError ? e.message : '처리 중 오류가 생겼어요. 잠시 후 다시 시도해 주세요.' }, 500);
  }
};
