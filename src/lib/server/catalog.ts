// 기준 데이터(품목표·질문표·규칙표·표시항목 틀 등)를 D1에서 한 번에 읽어 메모리에 둔다.
// 판정 엔진은 이 메모리 사본만 보고 동기로 돌아가므로 빠르고, 같은 입력이면 항상 같은 결과가 나온다.
// 기준 데이터를 D1에서 고치면 CACHE_TTL 안에 반영된다(Worker 인스턴스마다 따로 캐시).
import { getDb } from './d1';
import type { Category, CertType, ItemRole } from '../flow-types';

const CACHE_TTL = 5 * 60_000;

export interface ItemRow {
  id: number;
  code: string;
  name: string;
  category: Category;
  group1: string | null;
  group2: string | null;
  cert_type: CertType | null;
  base_standard: string | null;
  scope_text: string | null;
  source_doc: string | null;
  source_page: number | null;
  source_url: string | null;
  source_edition: string | null;
  needs_standard_text: number;
  extraction: string;
  review_status: string;
  verified_at: string | null;
}

export interface NodeRow {
  id: number;
  code: string;
  scope: 'global' | 'category' | 'item' | 'group' | 'trait';
  category: string | null;
  item_id: number | null;
  group_id: number | null;
  trait_code: string | null;
  sort_order: number;
  question_text: string;
  help_text: string | null;
  input_type: 'single_choice' | 'multi_choice' | 'text' | 'number';
  save_as: string;
  show_if: string | null;
}

export interface OptionRow {
  node_id: number;
  sort_order: number;
  label: string;
  value: string;
  sets: string;
  action: 'next' | 'escalate' | 'switch_item' | 'wait' | 'out_of_scope';
  action_target: string | null;
  action_message: string | null;
}

export interface GroupRow {
  id: number;
  code: string;
  name: string;
  kind: 'siblings' | 'cert_split' | 'age_class';
  selector_node: string | null;
}

export interface MemberRow {
  group_id: number;
  item_id: number;
  select_if: string | null;
  card_summary: string | null;
}

export interface ScopeRuleRow {
  id: number;
  item_id: number;
  rule_code: string;
  description: string;
  question_code: string | null;
  fail_if: string | null;
  on_fail: 'out_of_scope' | 'switch_cert' | 'switch_item' | 'escalate' | 'note';
  target_cert: CertType | null;
  target_item: string | null;
}

export interface TraitRow {
  item_id: number;
  trait_code: string;
  applies_if: string | null;
}

export interface TraitOutcomeRow {
  id: number;
  trait_code: string;
  answer_value: string;
  outcome: 'add_item' | 'cross_check' | 'escalate' | 'none';
  target: string | null;
  relation: ItemRole | null;
  basis: string | null;
}

export interface RelationRow {
  id: number;
  item_id: number;
  related_item_id: number;
  relation: 'exclusive' | 'parallel' | 'component';
  trigger_if: string | null;
  basis: string | null;
}

export interface FieldRow {
  id: number;
  template_code: string | null;
  item_id: number | null;
  sort_order: number;
  field_key: string;
  display_name: string;
  requirement: 'required' | 'recommended' | 'conditional';
  show_if: string | null;
  source: 'answer' | 'form' | 'fixed' | 'text_block';
  source_key: string | null;
  form_help: string | null;
  placeholder_text: string | null;
  condition_text: string | null;
}

export interface TextBlockRow {
  id: number;
  item_id: number | null;
  code: string;
  show_if: string | null;
  title: string | null;
  lines: string;
  needs_review: number;
}

export interface CertGuidanceRow {
  cert_type: CertType;
  display_name: string;
  summary: string;
  has_kc_mark: number;
  has_cert_no: number;
}

export interface Catalog {
  items: ItemRow[];
  itemByCode: Map<string, ItemRow>;
  itemById: Map<number, ItemRow>;
  aliasesByItem: Map<number, string[]>;
  nodes: NodeRow[];
  nodeByCode: Map<string, NodeRow>;
  optionsByNode: Map<number, OptionRow[]>;
  groupById: Map<number, GroupRow>;
  groupsByItem: Map<number, GroupRow[]>;
  membersByGroup: Map<number, MemberRow[]>;
  scopeRulesByItem: Map<number, ScopeRuleRow[]>;
  traitsByItem: Map<number, TraitRow[]>;
  traitOutcomes: Map<string, TraitOutcomeRow[]>; // key: `${trait}|${value}`
  relationsByItem: Map<number, RelationRow[]>;
  templateByItem: Map<number, string>;
  fieldsByTemplate: Map<string, FieldRow[]>;
  fieldsByItem: Map<number, FieldRow[]>;
  blocksByItem: Map<number, TextBlockRow[]>;
  mergeRules: Map<string, string>;
  certGuidance: Map<CertType, CertGuidanceRow>;
  sourcePriority: Map<string, number>;
}

let cache: { at: number; cat: Catalog } | null = null;
let loading: Promise<Catalog> | null = null;

const group = <T, K>(rows: T[], key: (r: T) => K) => {
  const m = new Map<K, T[]>();
  for (const r of rows) {
    const k = key(r);
    const list = m.get(k);
    if (list) list.push(r);
    else m.set(k, [r]);
  }
  return m;
};

async function fetchCatalog(): Promise<Catalog> {
  const db = getDb();
  const q = (sql: string) => db.prepare(sql);
  // 한 번의 왕복(batch)으로 기준 표 전체를 읽는다
  const res = await db.batch([
    q('SELECT * FROM items ORDER BY id'),
    q('SELECT item_id, alias FROM item_aliases'),
    q('SELECT * FROM question_nodes ORDER BY sort_order, id'),
    q('SELECT * FROM question_options ORDER BY node_id, sort_order, id'),
    q('SELECT * FROM item_groups ORDER BY id'),
    q('SELECT * FROM item_group_members'),
    q('SELECT * FROM item_scope_rules ORDER BY id'),
    q('SELECT item_id, trait_code, applies_if FROM item_traits'),
    q('SELECT * FROM trait_outcomes ORDER BY id'),
    q('SELECT * FROM item_relations ORDER BY id'),
    q('SELECT item_id, template_code FROM item_templates'),
    q('SELECT * FROM label_fields ORDER BY sort_order, id'),
    q('SELECT id, item_id, code, show_if, title, lines, needs_review FROM text_blocks ORDER BY id'),
    q('SELECT field_key, merge_mode FROM field_merge_rules'),
    q('SELECT * FROM cert_guidance'),
    q('SELECT kind, priority FROM source_priority'),
  ]);
  const r = <T>(i: number) => (res[i].results ?? []) as T[];

  const items = r<ItemRow>(0);
  const groups = r<GroupRow>(4);
  const groupById = new Map(groups.map((g) => [g.id, g]));
  const members = r<MemberRow>(5);
  const fields = r<FieldRow>(11);

  return {
    items,
    itemByCode: new Map(items.map((i) => [i.code, i])),
    itemById: new Map(items.map((i) => [i.id, i])),
    aliasesByItem: new Map([...group(r<{ item_id: number; alias: string }>(1), (a) => a.item_id)].map(([k, v]) => [k, v.map((a) => a.alias)])),
    nodes: r<NodeRow>(2),
    nodeByCode: new Map(r<NodeRow>(2).map((n) => [n.code, n])),
    optionsByNode: group(r<OptionRow>(3), (o) => o.node_id),
    groupById,
    groupsByItem: new Map([...group(members, (m) => m.item_id)].map(([k, ms]) => [k, ms.map((m) => groupById.get(m.group_id)!).filter(Boolean)])),
    membersByGroup: group(members, (m) => m.group_id),
    scopeRulesByItem: group(r<ScopeRuleRow>(6), (x) => x.item_id),
    traitsByItem: group(r<TraitRow>(7), (x) => x.item_id),
    traitOutcomes: group(r<TraitOutcomeRow>(8), (x) => `${x.trait_code}|${x.answer_value}`),
    relationsByItem: group(r<RelationRow>(9), (x) => x.item_id),
    templateByItem: new Map(r<{ item_id: number; template_code: string }>(10).map((t) => [t.item_id, t.template_code])),
    fieldsByTemplate: group(
      fields.filter((f) => f.template_code),
      (f) => f.template_code!,
    ),
    fieldsByItem: group(
      fields.filter((f) => f.item_id !== null),
      (f) => f.item_id!,
    ),
    blocksByItem: group(
      r<TextBlockRow>(12).filter((b) => b.item_id !== null),
      (b) => b.item_id!,
    ),
    mergeRules: new Map(r<{ field_key: string; merge_mode: string }>(13).map((m) => [m.field_key, m.merge_mode])),
    certGuidance: new Map(r<CertGuidanceRow>(14).map((g) => [g.cert_type, g])),
    sourcePriority: new Map(r<{ kind: string; priority: number }>(15).map((p) => [p.kind, p.priority])),
  };
}

/** 요청 시작 시 한 번 호출. 캐시가 살아 있으면 바로 돌려준다. */
export async function loadCatalog(): Promise<Catalog> {
  if (cache && Date.now() - cache.at < CACHE_TTL) return cache.cat;
  loading ??= fetchCatalog()
    .then((cat) => {
      cache = { at: Date.now(), cat };
      return cat;
    })
    .finally(() => {
      loading = null;
    });
  return loading;
}

/** 동기 접근 (loadCatalog 이후에만) */
export function cat(): Catalog {
  if (!cache) throw new Error('기준 데이터가 아직 로드되지 않았어요 (loadCatalog 먼저 호출)');
  return cache.cat;
}
