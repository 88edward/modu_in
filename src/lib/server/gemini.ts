// Gemini API: 업로드 문서 → 텍스트 + 판정용 값 추출, 그리고 (애매할 때만) 품목 후보 추천
// API 키는 서버(Worker)에서만 읽는다 — 배포: wrangler secret put GEMINI_API_KEY / 로컬: .dev.vars. 브라우저로 내려가지 않음.
import { env as cfEnv } from 'cloudflare:workers';

const API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

function env(name: 'GEMINI_API_KEY' | 'GEMINI_MODEL'): string | undefined {
  return (cfEnv as unknown as Record<string, string | undefined>)[name] || undefined;
}

/** Uint8Array → base64 (Workers 에는 Buffer 가 없어서 직접 변환) */
function toBase64(bytes: Uint8Array): string {
  let bin = '';
  const CHUNK = 0x8000;
  for (let i = 0; i < bytes.length; i += CHUNK) bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  return btoa(bin);
}

// 기본 모델. Google 이 모델을 내리면 404 가 나므로, 그때는 wrangler.jsonc 의 vars.GEMINI_MODEL 로 바꾼다
export const geminiModel = () => env('GEMINI_MODEL') || 'gemini-3.8-flash';
export const hasGeminiKey = () => Boolean(env('GEMINI_API_KEY'));

export class GeminiError extends Error {}

/** 추출 대상 값. key 는 variables 테이블 이름과 같다. */
export const FACT_KEYS = {
  product_name: '제품명(자료에 적힌 그대로)',
  generic_names: '일반 품목명 후보 1~4개, 쉼표로 구분 (예: "선풍기, 탁상용 선풍기"). 상표·모델명 제외',
  main_function: '주된 기능 한 문장 (사람들이 이 제품을 무엇 때문에 사는지)',
  model_name: '모델명',
  maker: '제조자명',
  importer: '수입자명',
  country: '제조국',
  address_phone: '주소 및 전화번호',
  as_contact: 'A/S 연락처',
  rating: '정격 표기 원문 (예: AC 220 V 60 Hz 45 W)',
  voltage_type: '전원 종류: AC | DC | AC/DC',
  voltage_v: '입력 전압 숫자(V)',
  power_w: '소비전력 숫자(W)',
  frequency_hz: '주파수 숫자(Hz)',
  cert_no: '인증·신고번호 (여러 개면 쉼표)',
  cert_type_text: '자료에 적힌 인증 구분 원문 (안전인증/안전확인/공급자적합성확인 등)',
  battery: '배터리: none | rechargeable | dry_cell',
  charger_included: '충전기 동봉: yes | no',
  has_wireless: '블루투스·와이파이 등 무선 기능: yes | no',
  food_contact: '음식·음료가 직접 닿는 부분: yes | no',
  mouth_contact: '입에 넣거나 빠는 제품: yes | no',
  has_magnet: '떨어질 수 있는 자석: yes | no',
  min_age: '사용 가능 최소 연령 숫자(세)',
  max_age: '사용 가능 최대 연령 숫자(세)',
  mfg_date: '제조연월',
  material_note: '주요 재질',
} as const;

export type FactKey = keyof typeof FACT_KEYS;

export interface ExtractedFact {
  key: FactKey;
  value: string;
  evidence: string;
  confidence: number;
}

/** 인증서 한 장 (여러 장을 묶은 PDF 면 장마다 하나) */
export interface CertEntry {
  certNo: string;
  modelName: string;
  seriesModels: string;
  productName: string;
  rating: string;
  certType: string;
}

export interface FileExtraction {
  docType: 'certificate' | 'manual' | 'photo';
  text: string;
  facts: ExtractedFact[];
  certificates: CertEntry[];
}

const EXTRACT_SCHEMA = {
  type: 'OBJECT',
  properties: {
    doc_type: { type: 'STRING', enum: ['certificate', 'manual', 'photo'] },
    text: { type: 'STRING' },
    facts: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          key: { type: 'STRING', enum: Object.keys(FACT_KEYS) },
          value: { type: 'STRING' },
          evidence: { type: 'STRING' },
          confidence: { type: 'NUMBER' },
        },
        required: ['key', 'value', 'evidence', 'confidence'],
      },
    },
    certificates: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          cert_no: { type: 'STRING' },
          model_name: { type: 'STRING' },
          series_models: { type: 'STRING' },
          product_name: { type: 'STRING' },
          rating: { type: 'STRING' },
          cert_type: { type: 'STRING' },
        },
        required: ['cert_no', 'model_name'],
      },
    },
  },
  required: ['doc_type', 'text', 'facts', 'certificates'],
};

const EXTRACT_PROMPT = `당신은 한국 KC 제품 표시사항 작성을 돕는 문서 판독기입니다.
첨부된 자료(인증서·시험성적서·설명서·제품 사진·라벨 사진)를 읽고 JSON으로 답하세요.

1. doc_type: 인증서/시험성적서면 "certificate", 설명서·사양서·카탈로그면 "manual", 제품·라벨·포장 사진이면 "photo".
2. text: 자료의 글자를 빠짐없이 텍스트로 옮기세요(표는 "항목: 값" 줄로). 최대 15000자.
3. facts: 아래 key 중 자료에서 **확인되는 것만** 넣으세요. 자료에 없으면 넣지 마세요. 추측 금지.
${Object.entries(FACT_KEYS)
  .map(([k, d]) => `   - ${k}: ${d}`)
  .join('\n')}
   - value 는 위 형식대로(숫자는 숫자만, yes/no 값은 yes 또는 no).
   - evidence 에는 근거가 된 자료 속 문구를 짧게 그대로 옮기세요.
   - confidence 는 0~1 (글자가 선명하고 명시적이면 0.9 이상, 추론이면 0.6 이하).
   - generic_names 는 자료에 직접 없더라도 제품이 무엇인지 분명하면 일반 명칭으로 적어도 됩니다(confidence 0.7 이하).
4. certificates: 자료에 KC 인증서·신고확인증이 있으면 **인증서 한 장마다** 하나씩 넣으세요.
   여러 모델의 인증서를 묶은 파일이면 장마다 따로 넣어야 합니다. 인증서가 없으면 빈 배열.
   - cert_no: 그 장의 인증·신고번호 / model_name: 기본모델명 / series_models: 파생모델명(쉼표 구분, 없으면 빈칸)
   - product_name: 제품명 / rating: 정격 표기 원문 그대로 (예: 1P, AC 240/415 V, 100 A, 50 kA) / cert_type: 안전인증·안전확인 등 원문
   - 이때 facts 의 cert_no·model_name·rating 에는 여러 장의 값을 섞어 쓰지 말고, 첫 장의 값만 넣으세요.`;

async function callGemini(parts: unknown[], schema: unknown, timeoutMs = 90_000): Promise<unknown> {
  const key = env('GEMINI_API_KEY');
  if (!key) throw new GeminiError('GEMINI_API_KEY가 설정되지 않았어요. 프로젝트 폴더의 .env 파일에 키를 넣어 주세요.');

  const res = await fetch(`${API_BASE}/${geminiModel()}:generateContent`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
    signal: AbortSignal.timeout(timeoutMs),
    body: JSON.stringify({
      contents: [{ role: 'user', parts }],
      generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: schema },
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    const msg = (() => {
      try {
        return JSON.parse(body).error?.message as string;
      } catch {
        return body.slice(0, 200);
      }
    })();
    throw new GeminiError(`Gemini 요청 실패 (${res.status}): ${msg}`);
  }
  const data = (await res.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[];
    promptFeedback?: { blockReason?: string };
  };
  if (data.promptFeedback?.blockReason) throw new GeminiError(`Gemini가 요청을 거부했어요: ${data.promptFeedback.blockReason}`);
  const text = data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  try {
    return JSON.parse(text);
  } catch {
    throw new GeminiError('Gemini 응답을 해석하지 못했어요. 다시 시도해 주세요.');
  }
}

export async function extractFromFile(file: { name: string; mime: string; data: Uint8Array }): Promise<FileExtraction> {
  const isText = file.mime.startsWith('text/');
  const filePart = isText
    ? { text: `--- 파일: ${file.name} ---\n${new TextDecoder().decode(file.data).slice(0, 60_000)}` }
    : { inlineData: { mimeType: file.mime, data: toBase64(file.data) } };

  const out = (await callGemini([filePart, { text: `파일명: ${file.name}\n\n${EXTRACT_PROMPT}` }], EXTRACT_SCHEMA)) as {
    doc_type?: string;
    text?: string;
    facts?: { key: string; value: string; evidence?: string; confidence?: number }[];
    certificates?: { cert_no?: string; model_name?: string; series_models?: string; product_name?: string; rating?: string; cert_type?: string }[];
  };

  const s = (v: unknown) => (typeof v === 'string' ? v.trim().slice(0, 300) : '');
  const certificates: CertEntry[] = (out.certificates ?? [])
    .map((c) => ({
      certNo: s(c.cert_no),
      modelName: s(c.model_name),
      seriesModels: s(c.series_models),
      productName: s(c.product_name),
      rating: s(c.rating),
      certType: s(c.cert_type),
    }))
    .filter((c) => c.certNo || c.modelName);

  const docType = (['certificate', 'manual', 'photo'] as const).find((d) => d === out.doc_type) ?? 'manual';
  const facts: ExtractedFact[] = (out.facts ?? [])
    .filter((f) => f.key in FACT_KEYS && typeof f.value === 'string' && f.value.trim() !== '')
    .map((f) => ({
      key: f.key as FactKey,
      value: f.value.trim(),
      evidence: (f.evidence ?? '').slice(0, 300),
      confidence: Math.max(0, Math.min(1, Number(f.confidence) || 0.5)),
    }));
  return { docType, text: (out.text ?? '').slice(0, 20_000), facts, certificates };
}

/** 규칙 검색으로 후보를 못 찾았을 때만: 품목표 목록을 주고 가까운 품목 code 를 고르게 한다. */
export async function suggestItems(
  description: string,
  catalogue: { code: string; name: string; category: string; group: string | null }[],
): Promise<{ code: string; reason: string }[]> {
  const list = catalogue.map((c) => `${c.code}|${c.name}|${c.category}|${c.group ?? ''}`).join('\n');
  const schema = {
    type: 'OBJECT',
    properties: {
      candidates: {
        type: 'ARRAY',
        items: {
          type: 'OBJECT',
          properties: { code: { type: 'STRING' }, reason: { type: 'STRING' } },
          required: ['code', 'reason'],
        },
      },
    },
    required: ['candidates'],
  };
  const prompt = `아래는 한국 KC 표시사항 품목표입니다 (code|품목명|분야|분류).
제품 설명을 보고, 이 제품의 "주된 기능" 기준으로 해당할 수 있는 품목을 최대 5개 고르세요.
- 겉모습(전동, 어린이용, 무선)보다 주된 기능을 우선하세요.
- 확실히 해당하지 않으면 빈 배열을 돌려주세요. 목록에 없는 code 를 만들지 마세요.
- reason 은 한 문장 한국어.

제품 설명:
${description}

품목표:
${list}`;
  const out = (await callGemini([{ text: prompt }], schema, 60_000)) as { candidates?: { code: string; reason: string }[] };
  const valid = new Set(catalogue.map((c) => c.code));
  return (out.candidates ?? []).filter((c) => valid.has(c.code)).slice(0, 5);
}
