// 표시 초안 생성 — "공통 틀(label_templates) + 품목별 차이(label_fields.item_id)"를 합친다.
// 품목마다 표시사항을 복사해 두지 않고, 틀 한 장을 여러 품목이 함께 쓴다.
// 여러 품목이 겹치면 field_merge_rules 로 합친다: dedupe(한 번만) | list(모두 나열) | strictest(가장 엄격한 쪽)
import { cat, type FieldRow } from './catalog';
import { evalCond, type Vars } from './conditions';
import type { ItemRow } from './match';
import type { ResolvedFact } from './session';
import { type CertType, type Draft, type DraftRow, type ItemRole, type ProcessType } from '../flow-types';
import { FACT_LABEL } from './facts';

export interface DraftItem {
  item: ItemRow | null;
  name: string;
  role: ItemRole;
  basis: string;
}

const LOCATION: Record<ItemRole, string> = {
  primary: '제품 표면 또는 최소 포장단위',
  parallel: '제품 표면 (주 표시와 함께)',
  component: '구성품 본체',
};

/** 라벨 칸 ↔ 자료에서 뽑은 값 */
const FIELD_FACT: Record<string, string> = {
  product_name: 'product_name',
  model_name: 'model_name',
  maker: 'maker',
  importer: 'importer',
  country: 'country',
  address_phone: 'address_phone',
  as_contact: 'as_contact',
  rating: 'rating',
  mfg_date: 'mfg_date',
  cert_no: 'cert_no',
};

export function buildDraft(input: {
  typedName: string;
  items: DraftItem[];
  vars: Vars;
  facts: Map<string, ResolvedFact>;
  processTypes: ProcessType[];
  notes: string[];
  escalations: string[];
  /** 빈 칸 채우기 답 (행 key → 값). 값이 있으면 자료·답변보다 우선 */
  fills?: Map<string, string>;
}): Draft {
  const { items, vars, facts } = input;
  const fills = input.fills ?? new Map<string, string>();
  const fact = (k: string) => facts.get(k)?.value ?? '';
  const c = cat();
  const mergeRules = c.mergeRules;
  const guidance = c.certGuidance;

  const rows = new Map<string, DraftRow & { mode: string; parts: { item: string; value: string }[] }>();
  const unresolved: string[] = [];
  const displayMethods: Draft['displayMethods'] = [];
  const certSummary: Draft['certSummary'] = [];

  for (const di of items) {
    // DB 에 없는 구성품: 자리만 만들고 별도 판정 안내
    if (!di.item) {
      rows.set(`component:${di.name}`, {
        key: `component:${di.name}`,
        name: `${di.name} 표시`,
        requirement: 'required',
        value: '',
        placeholder: '(별도 품목으로 판정한 뒤 그 기준대로 표시)',
        help: di.basis,
        condition: null,
        multiline: false,
        origin: 'empty',
        location: di.role === 'component' ? `${di.name} 본체` : LOCATION[di.role],
        sources: [{ code: '-', name: di.name, basis: di.basis }],
        needsReview: true,
        mode: 'dedupe',
        parts: [],
      });
      unresolved.push(`${di.name}: ${di.basis}`);
      continue;
    }

    const it = di.item;
    const certType = (di.role === 'primary' ? (vars.cert_type as CertType) : it.cert_type) ?? it.cert_type;
    const itemVars: Vars = { ...vars, cert_type: certType, category: it.category };
    const g = certType ? guidance.get(certType) : undefined;
    if (certType && g) {
      certSummary.push({
        item: { code: it.code, name: it.name, category: it.category, certType: it.cert_type, group: it.group2 },
        certType,
        label: g.display_name,
        summary: g.summary,
        kcMark: g.has_kc_mark === 1,
        certNo: g.has_cert_no === 1,
      });
    }

    // 공통 틀 먼저, 그다음 품목별 추가 항목 (각각 sort_order 순)
    const tmpl = c.templateByItem.get(it.id);
    const fields: FieldRow[] = [...(tmpl ? (c.fieldsByTemplate.get(tmpl) ?? []) : []), ...(c.fieldsByItem.get(it.id) ?? [])];
    const blocks = c.blocksByItem.get(it.id) ?? [];
    const location = di.role === 'component' ? `${it.name} 본체` : LOCATION[di.role];
    const sourceRef = {
      code: it.code,
      name: it.name,
      basis: [it.source_doc, it.source_page ? `${it.source_page}쪽` : null, it.source_edition].filter(Boolean).join(' · ') || '근거 정보 없음',
    };

    for (const f of fields) {
      if (f.show_if && !evalCond(f.show_if, itemVars)) continue;

      let value = '';
      let origin: DraftRow['origin'] = 'empty';
      let multiline = false;
      let needsReview = false;

      if (f.source === 'fixed') {
        if (f.source_key === 'KC') {
          if (vars.cert_status === 'done') {
            value = 'KC마크 (도안)';
            origin = 'fixed';
          }
        } else if (f.source_key) {
          // 정해진 문구 그대로 (예: 어린이제품 안내문구, "만8세 이상만 사용하시오")
          value = f.source_key;
          origin = 'fixed';
        }
      } else if (f.source === 'answer' && f.source_key) {
        const v = itemVars[f.source_key];
        if (v !== undefined && v !== null && v !== '') {
          value = Array.isArray(v) ? v.join(', ') : String(v);
          origin = 'answer';
        }
      } else if (f.source === 'text_block' && f.source_key) {
        const picked = blocks.filter((b) => b.code === f.source_key && evalCond(b.show_if, itemVars));
        const lines = picked.flatMap((b) => safeLines(b.lines));
        // 품목에 해당 문구가 없는 선택 칸(경고문구·취급상 주의 등)은 표에서 뺀다
        if (!lines.length && f.requirement !== 'required') continue;
        if (lines.length) {
          value = lines.join('\n');
          origin = 'text_block';
          multiline = true;
          needsReview = picked.some((b) => b.needs_review === 1);
        }
      } else if (f.source === 'form') {
        if (f.field_key === 'maker_or_importer') value = vars.is_import ? fact('importer') || fact('maker') : fact('maker');
        else if (f.field_key === 'product_name') value = fact('product_name') || input.typedName;
        else if (f.field_key === 'rating') value = fact('rating') || composeRating(facts);
        else if (f.field_key === 'age') value = composeAge(facts);
        else if (FIELD_FACT[f.field_key]) value = fact(FIELD_FACT[f.field_key]);
        if (value) origin = 'document';
      }

      let mode = mergeRules.get(f.field_key) ?? 'item';
      let key = mode === 'item' ? `${it.code}:${f.field_key}` : f.field_key;
      // 품목별 추가 항목이 공통 틀 항목과 같은 뜻이면(괄호 설명만 다름) 한 번만 보여주고 근거·조건을 합친다
      if (mode === 'item') {
        const same = [...rows.values()].find((r) => r.mode !== 'item' && baseName(r.name) === baseName(f.display_name));
        if (same) {
          key = same.key;
          mode = same.mode;
          const extra = f.display_name.match(/\((.*)\)?/)?.[1];
          if (extra && !same.help?.includes(extra)) same.help = [same.help, `품목 기준: ${extra}`].filter(Boolean).join(' / ');
        }
      }
      // 사용자가 빈 칸 채우기에서 직접 적은 값
      const filled = fills.get(key);
      if (filled) {
        value = filled;
        origin = 'answer';
        multiline = false;
      }
      const existing = rows.get(key);

      if (!existing) {
        rows.set(key, {
          key,
          name: mode === 'item' && items.filter((x) => x.item).length > 1 ? `${f.display_name} (${it.name})` : f.display_name,
          requirement: f.requirement,
          value,
          placeholder: f.placeholder_text,
          help: f.form_help,
          condition: f.condition_text,
          multiline: multiline || f.field_key === 'caution' || f.field_key === 'std_marks',
          origin,
          location: f.source === 'text_block' && f.source_key === 'std_marks' ? `${location} (규격에서 정한 위치)` : location,
          sources: [sourceRef],
          needsReview,
          mode,
          parts: value ? [{ item: it.name, value }] : [],
        });
        continue;
      }

      // 병합
      if (!existing.sources.some((s) => s.code === it.code)) existing.sources.push(sourceRef);
      existing.needsReview ||= needsReview;
      if (existing.requirement !== 'required' && f.requirement === 'required') existing.requirement = 'required';
      if (!value) continue;
      if (mode === 'list') {
        existing.parts.push({ item: it.name, value });
        if (f.field_key === 'cert_no') {
          existing.value = [...new Set(existing.parts.map((p) => p.value))].join('\n');
        } else {
          existing.value = [...new Set(existing.parts.flatMap((p) => p.value.split('\n')))].join('\n');
        }
        existing.multiline = true;
        if (existing.origin === 'empty') existing.origin = origin;
      } else if (mode === 'strictest') {
        if (it.category === 'kids' || !existing.value) {
          existing.value = value;
          existing.origin = origin;
        }
      } else if (!existing.value) {
        existing.value = value;
        existing.origin = origin;
      }
    }

    // 표시 방법
    const dm = blocks
      .filter((b) => b.code === 'display_method' && evalCond(b.show_if, itemVars))
      .flatMap((b) => safeLines(b.lines));
    if (dm.length) displayMethods.push({ item: it.name, lines: dm });

    // 확정 안 된 부분
    if (!it.verified_at) unresolved.push(`${it.name}: 근거 자료(${it.source_edition ?? '판 정보 없음'})가 최신 개정판인지 확인이 필요해요.`);
    if (it.needs_standard_text)
      unresolved.push(
        it.category === 'kids'
          ? `${it.name}: 경고문구 일부가 가이드에 그림으로만 있어요 — ${shorten(it.base_standard)} 원문에서 문구 확인.`
          : `${it.name}: 추가 표시사항 일부가 KC 규격 원문에만 있어요 — ${shorten(it.base_standard)} 확인.`,
      );
  }

  const outRows = [...rows.values()].map(({ mode: _m, parts: _p, ...r }) => r);

  const empty = outRows.filter((r) => !r.value && r.requirement === 'required').map((r) => r.name);
  if (empty.length) unresolved.unshift(`아직 비어 있는 필수 항목: ${empty.join(', ')}`);
  for (const r of outRows) if (r.condition && !r.value) unresolved.push(`'${r.name}'은(는) "${r.condition}" 경우에만 표시해요 — 해당하는지 확인해 주세요.`);
  if (outRows.some((r) => r.needsReview)) unresolved.push('안전기준 표시사항·주의사항 문구는 가이드북 자동 추출본이에요. 원문과 대조해 주세요.');
  if (vars.cert_status && vars.cert_status !== 'done') unresolved.push('인증 전이라 KC마크·인증번호 자리는 비워 두었어요. 인증 후 채워 주세요.');
  for (const [k, f] of facts) if (f.conflict.length) unresolved.push(`${FACT_LABEL[k] ?? k}: 자료마다 값이 달라요 (${[f.value, ...f.conflict].join(' / ')}).`);
  unresolved.push(...input.escalations);

  return {
    productName: fact('product_name') || input.typedName,
    processTypes: input.processTypes,
    certSummary,
    items: items.map((i) => ({
      item: i.item ? { code: i.item.code, name: i.item.name, category: i.item.category, certType: i.item.cert_type, group: i.item.group2 } : null,
      name: i.name,
      role: i.role,
      basis: i.basis,
    })),
    rows: outRows,
    displayMethods,
    unresolved: [...new Set(unresolved)],
    notes: input.notes,
  };
}

const baseName = (s: string) => s.replace(/\(.*$/, '').replace(/\s/g, '');

function safeLines(json: string): string[] {
  try {
    const v = JSON.parse(json);
    return Array.isArray(v) ? v.map(String).filter((s) => s.trim()) : [];
  } catch {
    return [];
  }
}

function composeRating(facts: Map<string, ResolvedFact>): string {
  const g = (k: string) => facts.get(k)?.value;
  const parts = [g('voltage_type'), g('voltage_v') && `${g('voltage_v')} V`, g('frequency_hz') && `${g('frequency_hz')} Hz`, g('power_w') && `${g('power_w')} W`].filter(Boolean);
  return parts.length > 1 ? parts.join(' ') : '';
}

function composeAge(facts: Map<string, ResolvedFact>): string {
  const min = facts.get('min_age')?.value;
  const max = facts.get('max_age')?.value;
  if (min && max) return `만 ${min}세 ~ 만 ${max}세`;
  if (min) return `만 ${min}세 이상`;
  return '';
}

function shorten(s: string | null, n = 60) {
  if (!s) return 'KC 규격';
  return s.length > n ? `${s.slice(0, n)}…` : s;
}

