// 자료에서 뽑은 값(facts) → 판정 엔진 변수(vars) 변환
// 엔진은 이 값으로 질문을 자동 응답(부족한 것만 물어봄)하고, 적용범위 조건을 계산한다.
import type { ResolvedFact } from './session';

/** 자동 응답에 쓰는 최소 확신도 (사용자가 확인한 값은 1) */
export const AUTO_CONFIDENCE = 0.6;

export const FACT_LABEL: Record<string, string> = {
  product_name: '제품명',
  generic_names: '일반 품목명',
  main_function: '주된 기능',
  model_name: '모델명',
  maker: '제조자',
  importer: '수입자',
  country: '제조국',
  address_phone: '주소·전화번호',
  as_contact: 'A/S 연락처',
  rating: '정격',
  voltage_type: '전원 종류',
  voltage_v: '전압(V)',
  power_w: '소비전력(W)',
  frequency_hz: '주파수(Hz)',
  cert_no: '인증·신고번호',
  cert_type_text: '인증 구분(자료 표기)',
  battery: '배터리',
  charger_included: '충전기 동봉',
  has_wireless: '무선 기능',
  food_contact: '음식 접촉',
  mouth_contact: '입에 넣는 제품',
  has_magnet: '자석',
  min_age: '최소 사용연령(세)',
  max_age: '최대 사용연령(세)',
  mfg_date: '제조연월',
  material_note: '재질',
};

/** 화면 표시 순서 */
export const FACT_ORDER = Object.keys(FACT_LABEL);

const num = (s: string | undefined) => {
  if (s === undefined) return undefined;
  const m = s.replace(/,/g, '').match(/-?\d+(\.\d+)?/);
  return m ? Number(m[0]) : undefined;
};
const yn = (s: string | undefined) => {
  if (!s) return undefined;
  const v = s.trim().toLowerCase();
  if (['yes', 'y', 'true', '예', '네', '있음', '있어요', 'o'].includes(v)) return 'yes';
  if (['no', 'n', 'false', '아니요', '아니오', '없음', '없어요', 'x'].includes(v)) return 'no';
  return undefined;
};
const KOREA = /^(대한민국|한국|국산|korea|republic of korea|south korea|kr)$/i;

export interface DerivedVar {
  value: unknown;
  confidence: number;
  from: string; // 근거 fact key
}

/** facts → 엔진 변수. 확신도가 낮은 값은 쓰지 않는다. */
export function deriveVars(facts: Map<string, ResolvedFact>): Map<string, DerivedVar> {
  const out = new Map<string, DerivedVar>();
  const f = (k: string) => {
    const x = facts.get(k);
    return x && x.confidence >= AUTO_CONFIDENCE ? x : undefined;
  };
  const set = (name: string, value: unknown, from: string) => {
    if (value === undefined || value === null || value === '') return;
    out.set(name, { value, confidence: facts.get(from)?.confidence ?? 0, from });
  };

  // 전원
  const vt = f('voltage_type')?.value.toUpperCase().replace(/\s/g, '');
  const power = vt === 'AC' ? 'ac' : vt === 'DC' ? 'dc' : undefined;
  set('power_source', power, 'voltage_type');
  const v = num(f('voltage_v')?.value);
  if (power && v !== undefined) set('is_low_voltage', (power === 'dc' && v <= 42) || (power === 'ac' && v <= 30) ? 'yes' : 'no', 'voltage_v');
  const w = num(f('power_w')?.value);
  if (w !== undefined) set('rated_input_kw', Math.round((w / 1000) * 1000) / 1000, 'power_w');
  set('rated_hz', num(f('frequency_hz')?.value), 'frequency_hz');

  const battery = f('battery')?.value.toLowerCase();
  if (battery === 'rechargeable' || battery === 'dry_cell') set('power_type', battery, 'battery');
  else if (power === 'ac') set('power_type', 'ac_plug', 'voltage_type');
  else if (battery === 'none' && !vt) set('power_type', 'none', 'battery');

  // 제조국 → 국산/수입
  const country = f('country')?.value.trim();
  if (country) {
    const domestic = KOREA.test(country);
    set('origin', domestic ? 'domestic' : 'import', 'country');
    set('is_import', !domestic, 'country');
  }

  for (const k of ['has_wireless', 'food_contact', 'mouth_contact', 'has_magnet', 'charger_included']) set(k, yn(f(k)?.value), k);

  // 연령
  const minAge = num(f('min_age')?.value);
  if (minAge !== undefined) set('age_group', minAge < 3 ? 'under_36m' : minAge <= 13 ? '36m_to_13y' : 'over_13y', 'min_age');

  // 인증서에 번호가 있으면 인증을 받은 것
  if (f('cert_no')) set('cert_status', 'done', 'cert_no');

  return out;
}

/** 품목표 검색어: 직접 입력한 이름 > 자료의 일반 품목명 > 자료의 제품명 */
export function searchTerms(typedName: string, facts: Map<string, ResolvedFact>, override?: string): string[] {
  const terms: string[] = [];
  const add = (s: string | undefined) => {
    for (const t of (s ?? '').split(/[,，/]/)) {
      const x = t.trim();
      if (x && !terms.includes(x)) terms.push(x);
    }
  };
  if (override) add(override);
  else {
    add(typedName);
    add(facts.get('generic_names')?.value);
    add(facts.get('product_name')?.value);
  }
  return terms;
}
