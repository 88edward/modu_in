// 판정 엔진 — 사용자의 답(steps)을 처음부터 다시 재생해서 "지금 보여줄 화면"을 계산한다.
// 같은 자료 + 같은 답이면 항상 같은 결과가 나온다 (판정 순서 고정).
//
//  1. 정보 모으기     자료에서 뽑은 값 확인 (facts_ok)
//  2. 전체 검색       6개 분야 품목표를 한꺼번에 검색 (규칙 → 애매하면 AI 추천)
//  3. 후보 개수 확인  0개: 검토 필요 / 1개: 범위 체크로 / 여러 개: 구분 질문
//  4. 주된 기능 확인  "무엇 때문에 사는지" 기준으로 후보 고르기
//  5. 전용 품목 우선  정확한 이름·전용 품목이 위로 (match.ts 점수)
//     ─ 인증구분 분기(cert_split)·연령 등급(age_class)은 DB 질문으로 자동 선택
//     ─ 적용범위 질문(global/category/item/trait) → item_scope_rules 평가
//  6. 구성품 분리     trait_outcomes·item_relations 로 병행/구성품 품목 추가
//  7. 표시 초안 출력  공통 틀 + 품목별 차이 병합 (draft.ts)
import { cat, type NodeRow, type OptionRow, type GroupRow, type ScopeRuleRow } from './catalog';
import { evalCond, type Vars } from './conditions';
import { searchItems, topTier, itemByCode, itemById, coreTerms, norm, type Candidate, type ItemRow } from './match';
import { deriveVars, searchTerms, FACT_LABEL, FACT_ORDER, type DerivedVar } from './facts';
import type { ResolvedFact, Step } from './session';
import type { CertEntry } from './gemini';
import { buildDraft, type DraftItem } from './draft';
import { buildTree } from './tree';
import {
  CATEGORY_LABEL,
  CERT_LABEL,
  type Category,
  type CertType,
  type ItemRef,
  type ItemRole,
  type ProcessType,
  type Screen,
  type SessionItemView,
  type SourceView,
  type HistoryStep,
  type Preview,
  type TreeNode,
  type TrailStep,
  type DraftRow,
} from '../flow-types';

// ------------------------------------------------------------------ 기준 데이터 조회 (메모리 사본)

const nodeByCode = (code: string): NodeRow | undefined => cat().nodeByCode.get(code);
const optionsOf = (nodeId: number): OptionRow[] => cat().optionsByNode.get(nodeId) ?? [];
/** 원문 오류·주의 메모 (text_blocks.code = 'source_note') */
const sourceNotes = (itemId: number) =>
  (cat().blocksByItem.get(itemId) ?? [])
    .filter((b) => b.code === 'source_note')
    .flatMap((r) => {
      try {
        return JSON.parse(r.lines) as string[];
      } catch {
        return [];
      }
    });
const groupsOf = (itemId: number): GroupRow[] => cat().groupsByItem.get(itemId) ?? [];

export const toRef = (i: ItemRow): ItemRef => ({ code: i.code, name: i.name, category: i.category, certType: i.cert_type, group: i.group2 });

const UNITS: Record<string, string> = { rated_input_kw: 'kW', rated_kva: 'kVA', rated_hz: 'Hz', bike_saddle_mm: 'mm', visible_transmittance: '%' };

/** 마지막 확인(catch_all)에서 고른 값 → 이어서 물어볼 공통분모 질문 */
const CATCH_ALL_FOLLOWUP: Record<string, string> = { power: 't_power', wireless: 't_wireless', food: 't_food', magnet: 't_magnet' };

/** trait_outcomes.target 이 품목 code 가 아닐 때 보여줄 이름 */
const TARGET_NAME: Record<string, string> = { battery: '내장 충전지(전지)' };

// ------------------------------------------------------------------ 입출력

export interface EngineInput {
  typedName: string;
  facts: Map<string, ResolvedFact>;
  docs: { name: string; kind: string; chars: number }[];
  steps: Step[];
  canUseAi: boolean;
}

export interface Outcome {
  vars: Vars;
  status: 'in_progress' | 'done' | 'escalated' | 'waiting' | 'out_of_scope';
  items: { itemId: number; role: ItemRole; addedBy: string }[];
  answers: { nodeId: number; value: string; auto: boolean }[];
}

export interface EngineExtras {
  history: HistoryStep[];
  preview: Preview | null;
  tree: TreeNode;
  trail: TrailStep[];
}

export type EngineResult =
  | { kind: 'screen'; screen: Screen; progress: number; outcome: Outcome; extras: EngineExtras }
  | { kind: 'need_ai'; stepKey: string; description: string };

interface SessionItem {
  item: ItemRow | null;
  name: string;
  role: ItemRole;
  basis: string;
}

class Stop {
  constructor(
    public screen: Screen,
    public progress: number,
    public status: Outcome['status'] = 'in_progress',
  ) {}
}

class NeedAi {
  constructor(
    public stepKey: string,
    public description: string,
  ) {}
}

// ------------------------------------------------------------------ 엔진

export function runEngine(input: EngineInput): EngineResult {
  const r = new Run(input);
  try {
    const screen = r.run();
    return { kind: 'screen', screen, progress: 6, outcome: r.outcome(r.escalations.length ? 'escalated' : 'done'), extras: r.extras() };
  } catch (e) {
    if (e instanceof Stop) return { kind: 'screen', screen: e.screen, progress: e.progress, outcome: r.outcome(e.status), extras: r.extras() };
    if (e instanceof NeedAi) return { kind: 'need_ai', stepKey: e.stepKey, description: e.description };
    throw e;
  }
}

class Run {
  vars: Vars = {};
  steps: Map<string, string>;
  derived: Map<string, DerivedVar>;
  /** 자료에서 뽑은 값. 인증서를 고르면 그 인증서 값으로 덮어쓴다 */
  facts: Map<string, ResolvedFact>;
  chosenCert: CertEntry | null = null;
  /** 빈 칸 채우기 답 (행 key → 값, '' = 나중에) */
  fills = new Map<string, string>();
  done = new Set<string>();
  ruleDone = new Set<number>();
  fromSets = new Set<string>(); // 보기의 sets 로 정해진 변수
  answers: { node: NodeRow; value: string; auto: boolean; label: string }[] = [];
  notes: string[] = [];
  escalations: string[] = [];
  conditional = false; // 주 규정에 조건이 붙었는지 (무선·인증구분 전환 등)
  items: SessionItem[] = [];
  primary: ItemRow | null = null;
  terms: string[] = [];
  // 화면 보조 정보 (트리·판정 경로)
  candidates: ItemRow[] = []; // 아직 품목을 고르기 전 후보
  trail: TrailStep[] = []; // 판정 경로 (분기가 갈린 순간들)
  via: string | null = null; // 주 품목으로 오게 한 질문·답
  decisions: { label: string; sub: string }[] = []; // 품목 확정 뒤의 분기 (인증구분 전환 등)

  constructor(private input: EngineInput) {
    this.steps = new Map(input.steps.map((s) => [s.key, s.value]));
    this.facts = new Map(input.facts);
    this.derived = deriveVars(this.facts);
    for (const s of input.steps) if (!s.system && s.key.startsWith('fill:')) this.fills.set(s.key.slice(5), s.value);
  }

  outcome(status: Outcome['status']): Outcome {
    return {
      vars: this.vars,
      status,
      items: this.items.filter((i) => i.item).map((i) => ({ itemId: i.item!.id, role: i.role, addedBy: i.basis.slice(0, 200) })),
      answers: this.answers.map((a) => ({ nodeId: a.node.id, value: a.value, auto: a.auto })),
    };
  }

  run(): Screen {
    this.collectInfo();
    this.pickCertificate();
    this.findPrimary();
    this.askScopeQuestions();
    this.splitComponents();
    this.checkSources();
    return this.finish();
  }

  // 1. 정보 모으기 ------------------------------------------------------
  collectInfo() {
    if (this.steps.has('facts_ok')) return;
    const facts = FACT_ORDER.filter((k) => this.facts.has(k)).map((k) => {
      const f = this.facts.get(k)!;
      return { key: k, label: FACT_LABEL[k], value: f.value, evidence: f.evidence, source: f.source, confidence: f.confidence, conflict: f.conflict };
    });
    const warnings: string[] = [];
    if (this.input.docs.length && !facts.length) warnings.push('자료에서 값을 찾지 못했어요. 아래에 직접 적어 주셔도 돼요.');
    if (facts.some((f) => f.conflict.length)) warnings.push('자료마다 다르게 적힌 값이 있어요. 인증서 값을 먼저 골라 두었어요.');
    throw new Stop({ type: 'facts', productName: this.input.typedName, docs: this.input.docs, facts, warnings }, 1);
  }

  // 1-2. 인증서 고르기: 여러 모델의 인증서를 묶은 자료면 이번에 만들 모델을 하나 고른다 ----

  /** 자료에서 읽은 인증서 목록 (파일별 시스템 기록을 합침, 인증번호 기준 중복 제거) */
  certificates(): CertEntry[] {
    const list: CertEntry[] = [];
    for (const s of this.input.steps) {
      if (!s.system || !s.key.startsWith('certs:')) continue;
      try {
        for (const c of JSON.parse(s.value) as CertEntry[]) {
          if (!list.some((x) => (x.certNo && x.certNo === c.certNo) || (!x.certNo && x.modelName === c.modelName))) list.push(c);
        }
      } catch {
        /* 깨진 기록은 무시 */
      }
    }
    // 인증서 목록이 없는데(예전 세션 등) 인증번호 칸에 번호가 여러 개 섞여 있으면 번호만으로 고르게 한다
    if (!list.length) {
      const nos = (this.facts.get('cert_no')?.value ?? '')
        .split(/[,，;/\s]+/)
        .map((x) => x.trim())
        .filter((x) => /^[A-Z0-9][A-Z0-9-]{5,}$/i.test(x));
      if (nos.length > 1) for (const certNo of nos) list.push({ certNo, modelName: '', seriesModels: '', productName: '', rating: '', certType: '' });
    }
    return list;
  }

  pickCertificate() {
    const list = this.certificates();
    if (!list.length) return;
    let chosen: CertEntry | undefined;
    const multi = list.length > 1;
    if (!multi) chosen = list[0];
    else {
      const raw = this.steps.get('cert_pick');
      if (raw === undefined) {
        throw new Stop(
          {
            type: 'question',
            stepKey: 'cert_pick',
            title: '어느 모델의 표시사항을 만들까요?',
            help: `올린 자료에 인증서가 ${list.length}장 들어 있어요. 표시사항은 모델마다 따로 만들어야 해서, 이번에 만들 모델을 하나 골라 주세요. 다른 모델은 처음부터 다시 하면 돼요.`,
            input: 'single_choice',
            options: list.map((c, i) => ({
              value: String(i),
              label: c.modelName || c.certNo,
              hint: [c.certNo && `인증번호 ${c.certNo}`, c.rating && `정격 ${c.rating}`, c.seriesModels && `파생모델 ${c.seriesModels}`].filter(Boolean).join(' · '),
            })),
          },
          1,
        );
      }
      chosen = list[Number(raw)];
    }
    if (!chosen) return;

    // 고른 인증서 값으로 덮어쓰기. 인증서가 한 장뿐이면 사용자가 직접 고친 값은 그대로 둔다
    const put = (key: string, value: string) => {
      if (!value) return;
      if (!multi && this.facts.get(key)?.confirmed) return;
      this.facts.set(key, { key, value, evidence: `인증서 ${chosen!.certNo || chosen!.modelName}`, source: '선택한 인증서', confidence: 1, confirmed: true, conflict: [] });
    };
    put('cert_no', chosen.certNo);
    put('model_name', chosen.modelName);
    put('rating', chosen.rating);
    put('product_name', chosen.productName);
    this.chosenCert = chosen;
    this.derived = deriveVars(this.facts);
    if (multi) this.trail.push({ label: '인증서(모델) 선택', detail: `${list.length}장 중 ${chosen.modelName || chosen.certNo}${chosen.certNo ? ` (${chosen.certNo})` : ''}` });
  }

  // 2~5. 전체 검색 → 후보 개수 → 주된 기능 → 전용 품목 -----------------
  findPrimary() {
    this.terms = searchTerms(this.input.typedName, this.facts, this.steps.get('search'));
    let cands = searchItems(this.terms);

    // 규칙 검색이 약하면(0개 또는 확정할 근거가 없는 부분 일치뿐) 그때만 AI 추천
    const weak = !cands.length || !cands[0].strong;
    const aiKey = `ai:${this.terms.join('|')}`;
    if (weak && this.terms.length && this.input.canUseAi) {
      const ai = this.steps.get(aiKey);
      if (ai === undefined) {
        const fn = this.facts.get('main_function')?.value;
        throw new NeedAi(aiKey, [`제품명/검색어: ${this.terms.join(', ')}`, fn ? `주된 기능: ${fn}` : ''].filter(Boolean).join('\n'));
      }
      const suggested = JSON.parse(ai) as { code: string; reason: string }[];
      for (const s of suggested) {
        const item = itemByCode(s.code);
        if (item && !cands.some((c) => c.item.code === s.code)) cands.push({ item, score: 58, reason: `AI 추천: ${s.reason}`, strong: false });
      }
      cands.sort((a, b) => b.score - a.score);
    }

    this.candidates = (topTier(cands).length > 1 ? topTier(cands) : cands.slice(0, 6)).map((c) => c.item);
    if (cands.length) {
      const cats = [...new Set(this.candidates.map((i) => CATEGORY_LABEL[i.category]))].join('·');
      this.trail.push({ label: '전체 품목 검색', detail: `'${this.terms.join(', ')}' → 후보 ${cands.length}개 (${cats})` });
    }

    const pick = this.steps.get('pick');
    if (pick === 'none') {
      throw new Stop(
        {
          type: 'end',
          kind: 'review',
          title: '전문가 확인이 필요해요',
          message: '품목표에서 이 제품에 맞는 품목을 확정하지 못했어요. 자료와 함께 검토를 요청해 주세요.',
          reasons: [`검색어: ${this.terms.join(', ') || '(없음)'}`, ...cands.slice(0, 3).map((c) => `가까운 후보: ${c.item.name} (${c.reason})`)],
        },
        2,
        'escalated',
      );
    }

    if (!cands.length) {
      throw new Stop(
        {
          type: 'no_match',
          tried: this.terms,
          message: this.terms.length
            ? '6개 분야 품목표에서 맞는 품목을 찾지 못했어요. 제품을 부르는 다른 이름으로 다시 찾아볼까요?'
            : '제품 이름을 알 수 없어요. 제품을 부르는 이름을 적어 주세요.',
        },
        2,
      );
    }

    let primary: ItemRow | undefined;
    let basis = '';
    const top = topTier(cands);

    if (pick) {
      primary = itemByCode(pick);
      basis = '주된 기능 기준으로 선택';
      if (primary) {
        this.via = '주된 기능으로 선택';
        this.trail.push({ label: '주된 기능 선택', detail: primary.name });
      }
    } else if (top.length === 1 && top[0].strong) {
      // 후보 1개 + 확실한 근거 → 그대로 확정하고 범위 체크로
      primary = top[0].item;
      basis = top[0].reason;
      this.via = '이름 일치';
      this.trail.push({ label: '후보 1개로 확정', detail: `${primary.name} (${top[0].reason})` });
    } else {
      primary = this.resolveAmongCandidates(top, cands);
      basis = '여러 후보 중 판정';
    }
    if (!primary) throw new Error('품목을 찾을 수 없습니다');

    // 같은 이름이 조건에 따라 인증구분/연령등급이 갈리면 DB 질문으로 자동 선택
    primary = this.resolveSplit(primary);
    this.setPrimary(primary, basis);
  }

  /** 1순위 후보가 여러 개 */
  resolveAmongCandidates(top: Candidate[], cands: Candidate[]): ItemRow {
    // 확실한 근거가 있는 후보들끼리만 DB 묶음으로 가른다. 부분 일치뿐이면 (c)에서 "여기에 없어요"까지 보여준다.
    const confident = top.every((c) => c.strong);
    const core = coreTerms(this.terms);
    const namedAs = (g: GroupRow) => core.includes(norm(g.name.replace(/\(.*?\)/g, '')));

    // (a) 모두 같은 인증구분 분기/연령 등급 묶음 → 아무거나 잡고 resolveSplit 에서 가른다
    //     (검색어가 묶음 이름 그대로면 — 예: 비비탄총 — 부분 일치여도 이 묶음이 맞다)
    const splitGroups = top.map((c) => groupsOf(c.item.id).filter((g) => g.kind !== 'siblings'));
    const commonSplit = splitGroups[0].find((g) => splitGroups.every((s) => s.some((x) => x.id === g.id)));
    if (commonSplit && (confident || namedAs(commonSplit))) return top[0].item;

    // (b) 모두 같은 형제 묶음 → DB 의 그룹 질문(pick_G-xxxx)
    const sib = top.map((c) => groupsOf(c.item.id).filter((g) => g.kind === 'siblings'));
    const commonSib = sib[0].find((g) => sib.every((s) => s.some((x) => x.id === g.id)));
    if (confident && commonSib?.selector_node) {
      const node = nodeByCode(commonSib.selector_node);
      if (node) {
        this.ask(node, { progress: 2 });
        const code = String(this.vars[node.save_as] ?? '');
        const item = itemByCode(code);
        if (item) {
          this.via = `${commonSib.name} 중 선택`;
          this.trail.push({ label: `형제 품목 선택 (${commonSib.name})`, detail: item.name });
          return item;
        }
        this.review('형제 품목 중 어느 것인지 정하지 못했어요.', [`묶음: ${commonSib.name}`]);
      }
    }

    // (c) 분야가 섞인 후보 → 주된 기능 기준으로 직접 고르기
    const fn = this.facts.get('main_function')?.value;
    const shown = top.length >= 2 ? top : cands.slice(0, 6);
    throw new Stop(
      {
        type: 'question',
        stepKey: 'pick',
        title: '이 제품의 주된 기능에 가장 가까운 품목을 골라 주세요',
        help: '사람들이 이 제품을 "무엇 때문에" 사는지가 기준이에요. 전동·어린이용·무선 같은 겉모습보다 주된 기능이 우선이에요.',
        note: fn ? `자료에서 찾은 주된 기능: ${fn}` : null,
        input: 'single_choice',
        options: [
          ...shown.map((c) => ({
            value: c.item.code,
            label: c.item.name,
            hint: [CATEGORY_LABEL[c.item.category], c.item.group2, c.item.cert_type ? CERT_LABEL[c.item.cert_type] : null].filter(Boolean).join(' · '),
            badge: c.reason.startsWith('AI') ? 'AI 추천' : c.score >= 95 ? '이름 일치' : undefined,
          })),
          { value: 'none', label: '여기에 없어요', hint: '전문가 확인으로 넘어가요' },
        ],
      },
      2,
    );
  }

  /** 인증구분 분기(cert_split)·연령 등급(age_class): 선택 질문에 답하면 select_if 로 품목이 정해진다 */
  resolveSplit(item: ItemRow): ItemRow {
    const g = groupsOf(item.id).find((x) => x.kind !== 'siblings' && x.selector_node);
    if (!g) return item;
    const node = nodeByCode(g.selector_node!);
    if (!node) return item;
    this.ask(node, { progress: 2 });
    const members = cat().membersByGroup.get(g.id) ?? [];
    const hits = members.filter((m) => m.select_if && evalCond(m.select_if, this.vars)).map((m) => itemById(m.item_id)!);
    if (hits.length) {
      // 조건에 맞는 품목이 여럿이면(예: 어린이 안경 → 생활용품 선글라스/안경테) 지금 품목 > 검색어와 가장 가까운 품목
      let chosen = hits.find((h) => h.code === item.code);
      if (!chosen && hits.length > 1) {
        const scored = searchItems(this.terms, { limit: 50 });
        chosen = hits
          .map((h) => ({ h, s: scored.find((c) => c.item.code === h.code)?.score ?? 0 }))
          .sort((a, b) => b.s - a.s)[0].h;
        this.notes.push(`${g.name}: 연령에 맞는 품목이 여럿이라 검색어와 가장 가까운 '${chosen.name}'로 판정했어요. 다르면 처음 화면에서 제품 이름을 더 구체적으로 적어 주세요.`);
      }
      chosen ??= hits[0];
      if (chosen.code !== item.code) this.notes.push(`${g.name}: 답변에 따라 '${chosen.name}'(${CERT_LABEL[chosen.cert_type!]}) 기준을 적용해요.`);
      const ans = this.answerLabel(node.code);
      this.via = `${node.question_text.replace(/\?$/, '')} → ${ans}`;
      this.trail.push({
        label: g.kind === 'age_class' ? '연령 등급 분기' : '인증구분 분기',
        detail: `${node.question_text} → ${ans} → ${chosen.name} (${CATEGORY_LABEL[chosen.category]} · ${CERT_LABEL[chosen.cert_type!]})`,
      });
      return chosen;
    }
    this.review(`'${g.name}'에서 조건에 맞는 품목을 정하지 못했어요.`, this.escalations);
  }

  /** 답한 질문의 보기 글자 */
  answerLabel(code: string): string {
    return this.answers.filter((a) => a.node.code === code).at(-1)?.label ?? String(this.steps.get(code) ?? '');
  }

  /** 가장 최근 답 "질문 → 답" (품목 전환 사유 표시용) */
  lastAnswerText(): string | null {
    const a = this.answers.at(-1);
    return a ? `${a.node.question_text.replace(/\?$/, '')} → ${a.label}` : null;
  }

  // ---------------------------------------------------------------- 화면 보조 정보

  extras(): EngineExtras {
    return {
      history: this.history(),
      preview: this.steps.has('facts_ok') ? this.preview() : null,
      tree: buildTree({
        candidates: this.candidates,
        primary: this.primary,
        primaryCert: (this.vars.cert_type as CertType | undefined) ?? null,
        via: this.via,
        decisions: this.decisions,
        related: this.items.filter((i) => i.role !== 'primary').map((i) => ({ item: i.item, name: i.name, role: i.role, basis: i.basis })),
      }),
      trail: this.trail,
    };
  }

  /** 지금까지 한 답 (시스템 기록 제외) → 위쪽 기록 선 */
  history(): HistoryStep[] {
    const fixed: Record<string, [string, number]> = {
      facts_ok: ['자료에서 찾은 값 확인', 1],
      search: ['다른 이름으로 다시 찾기', 2],
      pick: ['주된 기능으로 품목 선택', 2],
      source_ack: ['판정 근거 확인', 4],
      rules_ack: ['판정 결과 확인', 5],
    };
    return this.input.steps
      .filter((s) => !s.system)
      .map((s, index) => {
        if (fixed[s.key]) {
          const [title, stage] = fixed[s.key];
          const answer = s.key === 'pick' ? (itemByCode(s.value)?.name ?? (s.value === 'none' ? '여기에 없어요' : s.value)) : s.key === 'search' ? s.value : '확인';
          return { index, title, answer, stage };
        }
        if (s.key.startsWith('wait:')) return { index, title: '확인 보류', answer: '모르는 채로 진행', stage: 3 };
        if (s.key === 'cert_pick') {
          const c = this.certificates()[Number(s.value)];
          return { index, title: '인증서(모델) 선택', answer: c ? c.modelName || c.certNo : s.value, stage: 1 };
        }
        if (s.key.startsWith('fill:')) {
          const name = this.rowName(s.key.slice(5));
          return { index, title: `${name} 입력`, answer: s.value || '나중에 채우기', stage: 6 };
        }
        const node = nodeByCode(s.key);
        if (!node) return { index, title: s.key, answer: s.value, stage: 3 };
        const opts = optionsOf(node.id);
        let answer = s.value;
        if (node.input_type === 'multi_choice') {
          try {
            const vals = JSON.parse(s.value) as string[];
            answer = vals.length ? vals.map((v) => opts.find((o) => o.value === v)?.label ?? v).join(', ') : '해당 없음';
          } catch {
            /* 그대로 */
          }
        } else if (node.input_type === 'single_choice') answer = opts.find((o) => o.value === s.value)?.label ?? s.value;
        else if (node.input_type === 'number') answer = `${s.value} ${UNITS[node.save_as] ?? ''}`.trim();
        return { index, title: node.question_text, answer, stage: node.scope === 'group' ? 2 : 3 };
      });
  }

  /** 왼쪽 표시사항 미리보기: 품목이 정해지면 그 품목의 표시 틀, 아니면 공통 빈칸 */
  preview(): Preview {
    const facts = this.facts;
    const fact = (k: string) => facts.get(k)?.value ?? '';
    if (!this.primary) {
      const later = '(품목이 정해지면 채워져요)';
      const row = (key: string, name: string, value: string, placeholder: string | null = null, multiline = false) => ({
        key,
        name,
        value,
        placeholder,
        requirement: 'required' as const,
        origin: value ? ('document' as const) : ('empty' as const),
        multiline,
      });
      return {
        title: '품목 판정 전',
        subtitle: '공통 항목부터 채우고 있어요',
        rows: [
          row('kc', 'KC마크·인증번호', '', later),
          row('product_name', '제품명', fact('product_name') || this.input.typedName),
          row('model_name', '모델명', fact('model_name')),
          row('maker', '제조자명(수입자명)', this.vars.is_import ? fact('importer') || fact('maker') : fact('maker')),
          row('country', '제조국명', fact('country')),
          row('mfg_date', '제조년월', fact('mfg_date')),
          row('caution', '주의사항·품목별 표시', '', later, true),
        ],
      };
    }
    const d = { rows: this.draftRows() };
    const cert = this.vars.cert_type as CertType | undefined;
    return {
      title: this.primary.name,
      subtitle: [CATEGORY_LABEL[this.primary.category], cert ? CERT_LABEL[cert] : null].filter(Boolean).join(' · '),
      rows: d.rows.map((r) => ({ key: r.key, name: r.name, value: r.value, placeholder: r.placeholder, requirement: r.requirement, origin: r.origin, multiline: r.multiline })),
    };
  }

  setPrimary(item: ItemRow, basis: string) {
    this.primary = item;
    this.vars.category = item.category;
    this.vars.cert_type = item.cert_type;
    this.items = [{ item, name: item.name, role: 'primary', basis }];
  }

  // 3. 범위 체크: 적용범위·조건 질문 → item_scope_rules ---------------
  askScopeQuestions() {
    for (let guard = 0; guard < 5; guard++) {
      const item = this.primary!;
      const switched = this.askNodesFor(item) ?? this.applyScopeRules(item);
      if (!switched) return;
      const next = itemByCode(switched);
      if (!next || next.code === item.code) return;
      this.notes.push(`'${item.name}' → '${next.name}' 품목으로 전환했어요.`);
      const why = this.lastAnswerText();
      this.trail.push({ label: '품목 전환', detail: `${item.name} → ${next.name}${why ? ` (${why})` : ''}` });
      this.via = why ? `${item.name}에서 전환: ${why}` : `${item.name}에서 전환`;
      this.decisions = [];
      this.setPrimary(this.resolveSplit(next), '조건에 따라 품목 전환');
    }
  }

  nodesFor(item: ItemRow): NodeRow[] {
    const c = cat();
    // 적용범위 규칙이 쓰는 분야 질문 + 품목 전용 질문 + 해당하는 태그 질문 + 공통 질문 (nodes 는 sort_order, id 순)
    const ruleQs = new Set((c.scopeRulesByItem.get(item.id) ?? []).map((r) => r.question_code).filter(Boolean));
    const traits = new Set(
      (c.traitsByItem.get(item.id) ?? []).filter((t) => evalCond(t.applies_if, this.vars)).map((t) => t.trait_code),
    );
    return c.nodes.filter(
      (n) =>
        n.scope === 'global' ||
        (n.scope === 'category' && n.category === item.category && ruleQs.has(n.code)) ||
        (n.scope === 'item' && n.item_id === item.id) ||
        (n.scope === 'trait' && n.trait_code !== null && traits.has(n.trait_code)),
    );
  }

  /** 반환: switch_item 대상 code (있으면) */
  askNodesFor(item: ItemRow): string | undefined {
    const queue = this.nodesFor(item);
    for (let i = 0; i < queue.length; i++) {
      const node = queue[i];
      const target = this.ask(node, { progress: 3 }) ?? this.applyScopeRules(item, node.code);
      if (target) return target;
      // 답에 따라 새로 붙는 태그 질문(예: 전동 킥보드 → 전원 질문)을 이어서 묻는다
      for (const n of this.nodesFor(item)) if (!queue.some((x) => x.code === n.code)) queue.push(n);
      if (node.code === 'catch_all') {
        const picked = (this.vars.catch_all as string[] | undefined) ?? [];
        for (const v of picked) {
          const follow = CATCH_ALL_FOLLOWUP[v];
          if (v === 'power' && item.category === 'electric') continue; // 이미 전기용품
          if (follow && !queue.some((q) => q.code === follow)) {
            const n = nodeByCode(follow);
            if (n) queue.push(n);
          }
          if (v === 'mouth') {
            this.vars.mouth_contact = 'yes';
            this.escalations.push('입에 넣거나 빠는 제품이에요 — 식품용 기구·어린이제품 기준 교차 확인이 필요해요.');
          }
        }
      }
    }
    return undefined;
  }

  /**
   * 질문 하나 처리: 이미 답했거나 자료로 자동 응답 가능하면 적용, 아니면 질문 화면으로 멈춘다.
   * 반환: switch_item 대상 code
   */
  ask(node: NodeRow, opts: { progress: number }): string | undefined {
    if (this.done.has(node.code)) return undefined;
    if (node.show_if && !evalCond(node.show_if, this.vars)) return undefined;

    const options = optionsOf(node.id);
    let raw = this.steps.get(node.code);
    let auto = false;
    if (raw === undefined) {
      raw = this.autoAnswer(node, options);
      // 앞선 보기의 sets 로 이미 정해진 값이면 다시 묻지 않는다 (예: 수동 연필깎이 → 전원 없음)
      const known = this.vars[node.save_as];
      if (raw === undefined && node.input_type === 'single_choice' && this.fromSets.has(node.save_as) && known !== undefined && options.some((o) => o.value === String(known))) raw = String(known);
      auto = raw !== undefined;
    }
    if (raw === undefined) throw new Stop(this.questionScreen(node, options), opts.progress);
    this.done.add(node.code);

    // 값 저장
    if (node.input_type === 'multi_choice') {
      const values = safeArray(raw);
      this.vars[node.save_as] = values;
      const chosen = options.filter((o) => values.includes(o.value));
      chosen.forEach((o) => this.applySets(o.sets));
      this.answers.push({ node, value: raw, auto, label: chosen.map((o) => o.label).join(', ') || '해당 없음' });
      return undefined;
    }
    if (node.input_type === 'number') {
      this.vars[node.save_as] = Number(raw);
      this.answers.push({ node, value: raw, auto, label: `${raw} ${UNITS[node.save_as] ?? ''}`.trim() });
      return undefined;
    }
    if (node.input_type === 'text') {
      this.vars[node.save_as] = raw;
      this.answers.push({ node, value: raw, auto, label: raw });
      return undefined;
    }

    const opt = options.find((o) => o.value === raw);
    this.vars[node.save_as] = raw;
    if (!opt) return undefined;
    this.applySets(opt.sets);
    this.answers.push({ node, value: raw, auto, label: opt.label });

    switch (opt.action) {
      case 'escalate':
        this.escalations.push(opt.action_message ?? `${node.question_text} → ${opt.label}: 전문가 확인이 필요해요.`);
        return undefined;
      case 'out_of_scope':
        throw new Stop(
          {
            type: 'end',
            kind: 'out_of_scope',
            title: '이 기준의 적용 대상이 아니에요',
            message: opt.action_message ?? '답변하신 조건은 이 품목 기준의 적용 범위에서 빠져요.',
            item: this.primary ? toRef(this.primary) : null,
            reasons: [`${node.question_text} → ${opt.label}`],
          },
          3,
          'out_of_scope',
        );
      case 'wait':
        if (!this.steps.has(`wait:${node.code}`)) {
          throw new Stop({ type: 'wait', stepKey: `wait:${node.code}`, title: node.question_text, message: opt.action_message ?? '확인 후 다시 답해 주세요.' }, opts.progress, 'waiting');
        }
        this.escalations.push(`${node.question_text} — 확인하지 못한 채 진행했어요. (${opt.action_message ?? ''})`.trim());
        return undefined;
      case 'switch_item':
        return opt.action_target ?? undefined;
      default:
        return undefined;
    }
  }

  applySets(json: string) {
    const sets = safeObj(json);
    Object.assign(this.vars, sets);
    for (const k of Object.keys(sets)) this.fromSets.add(k);
  }

  autoAnswer(node: NodeRow, options: OptionRow[]): string | undefined {
    const d = this.derived.get(node.save_as);
    if (!d) return undefined;
    if (node.input_type === 'number') return Number.isFinite(Number(d.value)) ? String(d.value) : undefined;
    if (node.input_type === 'single_choice') {
      const v = String(d.value);
      // 형제 품목 고르기·연령 등급처럼 판정을 가르는 선택은 자동으로 넘기지 않는다
      if (node.scope === 'group') return undefined;
      return options.some((o) => o.value === v) ? v : undefined;
    }
    return undefined;
  }

  questionScreen(node: NodeRow, options: OptionRow[]): Screen {
    let defaultValue: string | string[] | null = null;
    if (node.code === 'catch_all') {
      const d = (k: string) => this.derived.get(k)?.value;
      const pre: string[] = [];
      if (d('power_source') || ['ac_plug', 'rechargeable', 'dry_cell'].includes(String(d('power_type')))) pre.push('power');
      if (d('has_wireless') === 'yes') pre.push('wireless');
      if (d('food_contact') === 'yes') pre.push('food');
      if (d('mouth_contact') === 'yes') pre.push('mouth');
      if (d('has_magnet') === 'yes') pre.push('magnet');
      defaultValue = pre;
    }
    return {
      type: 'question',
      stepKey: node.code,
      title: node.question_text,
      help: node.help_text,
      note: this.primary && node.scope !== 'global' ? `판정 중인 품목: ${this.primary.name} (${CATEGORY_LABEL[this.primary.category]})` : null,
      input: node.input_type,
      options: options.map((o) => ({ value: o.value, label: o.label })),
      defaultValue,
      unit: UNITS[node.save_as],
    };
  }

  /**
   * 적용범위 규칙 평가. onlyQuestion 을 주면 그 질문에 걸린 규칙만 (답하자마자 바로 판정 → 불필요한 질문을 줄임).
   * 한 번 평가한 규칙은 다시 보지 않는다.
   */
  applyScopeRules(item: ItemRow, onlyQuestion?: string): string | undefined {
    const rules: ScopeRuleRow[] = (cat().scopeRulesByItem.get(item.id) ?? []).filter((r) => !this.ruleDone.has(r.id) && (onlyQuestion === undefined || r.question_code === onlyQuestion));
    for (const r of rules) {
      this.ruleDone.add(r.id);
      if (!r.fail_if) {
        this.notes.push(r.description);
        continue;
      }
      if (!evalCond(r.fail_if, this.vars)) continue;
      switch (r.on_fail) {
        case 'out_of_scope':
          throw new Stop(
            { type: 'end', kind: 'out_of_scope', title: `'${item.name}' 기준의 적용 대상이 아니에요`, message: r.description, item: toRef(item), reasons: [r.description] },
            3,
            'out_of_scope',
          );
        case 'switch_cert':
          if (r.target_cert && this.vars.cert_type !== r.target_cert) {
            this.vars.cert_type = r.target_cert;
            this.conditional = true;
            this.notes.push(`${r.description} → ${CERT_LABEL[r.target_cert]}(으)로 적용해요.`);
            this.decisions.push({ label: `인증구분 → ${CERT_LABEL[r.target_cert]}`, sub: r.description });
            this.trail.push({ label: '인증구분 전환', detail: `${r.description} → ${CERT_LABEL[r.target_cert]}` });
          }
          break;
        case 'switch_item':
          if (r.target_item) return r.target_item;
          break;
        case 'escalate':
          this.escalations.push(r.description);
          break;
        default:
          this.notes.push(r.description);
      }
    }
    return undefined;
  }

  // 6. 구성품 분리 / 병행 품목 ------------------------------------------
  splitComponents() {
    const primary = this.primary!;
    const add = (si: SessionItem) => {
      if (si.item && this.items.some((x) => x.item?.code === si.item!.code)) return;
      if (!si.item && this.items.some((x) => !x.item && x.name === si.name)) return;
      this.items.push(si);
    };

    for (const a of this.answers.filter((x) => x.node.scope === 'trait' && x.node.trait_code)) {
      const outcomes = cat().traitOutcomes.get(`${a.node.trait_code}|${a.value}`) ?? [];
      for (const o of outcomes) {
        const basis = o.basis ?? `${a.node.question_text} → ${a.label}`;
        if (o.outcome === 'add_item') {
          const item = o.target ? itemByCode(o.target) : undefined;
          add(item ? { item, name: item.name, role: o.relation ?? 'component', basis } : { item: null, name: TARGET_NAME[o.target ?? ''] ?? o.target ?? '추가 품목', role: o.relation ?? 'component', basis });
        } else if (o.outcome === 'cross_check' && o.target) {
          const category = o.target as Category;
          if (category === primary.category) continue;
          this.conditional = true;
          const hit = category === 'electric' || category === 'living' ? searchItems(this.terms, { category: category, limit: 1 })[0] : undefined;
          if (hit?.strong) {
            add({ item: hit.item, name: hit.item.name, role: o.relation ?? 'parallel', basis: `${basis} (${hit.reason})` });
            continue;
          }
          const why =
            category === 'electric' || category === 'living'
              ? `${CATEGORY_LABEL[category]} 품목표에서 해당 품목을 확정하지 못했어요.`
              : `${CATEGORY_LABEL[category] ?? category} 기준은 아직 DB에 없어요.`;
          this.escalations.push(`${basis} — ${why}`);
          // 병행/구성품 관계가 정해진 교차 확인이면, 품목을 못 찾아도 표시 자리는 잡아 둔다 (예: 전기밥솥 + 식품접촉)
          if (o.relation) add({ item: null, name: `${CATEGORY_LABEL[category] ?? category} 기준`, role: o.relation, basis: `${basis} — ${why}` });
        } else if (o.outcome === 'escalate') {
          this.conditional = true;
          this.escalations.push(basis);
        } else if (o.basis) {
          this.notes.push(o.basis);
        }
      }
    }

    // DB 의 품목 관계 (병행·구성품)
    const rel = (cat().relationsByItem.get(primary.id) ?? []).filter((r) => r.relation === 'parallel' || r.relation === 'component');
    for (const r of rel) {
      if (!evalCond(r.trigger_if, this.vars)) continue;
      const item = itemById(r.related_item_id);
      if (item) add({ item, name: item.name, role: r.relation as ItemRole, basis: r.basis ?? '품목 관계' });
    }

    // 판정 원칙: 충전기·배터리가 독립 품목이면 그것만 따로 판정 (DB 에 연결표가 생기면 그쪽으로 이동)
    if (this.vars.charger_included === 'yes') {
      add({ item: null, name: '동봉 충전기', role: 'component', basis: '충전기는 본체와 별도 전기용품(전기충전기·교류어댑터 등)으로 따로 판정해요.' });
    }
  }

  // 최신 원문 확인 ---------------------------------------------------------
  sourceViews(): SourceView[] {
    return this.items
      .filter((i) => i.item)
      .map((i) => {
        const it = i.item!;
        const flags: string[] = [];
        if (!it.verified_at) flags.push(`최신 개정 여부 미확인 — 근거 자료가 '${it.source_edition ?? '판 정보 없음'}' 기준이에요`);
        if (it.extraction === 'auto' && it.review_status !== 'reviewed') flags.push('가이드북 자동 추출 데이터 (검수 전)');
        if (it.review_status === 'needs_fix') flags.push('수정이 필요하다고 표시된 품목이에요');
        if (it.needs_standard_text) flags.push(it.category === 'kids' ? '경고문구 일부가 가이드에 그림으로만 있어요 — 개별 안전기준 원문에서 문구 확인' : '추가 표시사항 일부가 KC 규격 원문에만 있어요');
        for (const n of sourceNotes(it.id)) flags.push(`원문 오류·주의: ${n}`);
        return {
          item: this.refFor(i),
          role: i.role,
          doc: it.source_doc,
          page: it.source_page,
          edition: it.source_edition,
          url: it.source_url,
          standard: it.base_standard,
          verifiedAt: it.verified_at,
          flags,
        };
      });
  }

  checkSources() {
    if (this.steps.has('source_ack')) return;
    throw new Stop({ type: 'source_check', sources: this.sourceViews() }, 4);
  }

  // 7. 추가 규칙 → 초안 ---------------------------------------------------
  processTypes(): ProcessType[] {
    const t: ProcessType[] = [];
    if (this.items.some((i) => i.role === 'component')) t.push('component');
    if (this.items.some((i) => i.role === 'parallel')) t.push('parallel');
    if (!t.length) t.push(this.conditional ? 'main_plus' : 'single');
    if (this.escalations.length) t.push('review');
    return t;
  }

  /** 화면용 품목 정보. 주 품목은 조건에 따라 바뀐 인증구분(vars.cert_type)을 보여준다 */
  refFor(i: SessionItem): ItemRef {
    const ref = toRef(i.item!);
    return i.role === 'primary' && this.vars.cert_type ? { ...ref, certType: this.vars.cert_type as CertType } : ref;
  }

  itemViews(): SessionItemView[] {
    return this.items.map((i) => ({ item: i.item ? this.refFor(i) : null, name: i.name, role: i.role, basis: i.basis }));
  }

  finish(): Screen {
    const processTypes = this.processTypes();
    if (!this.steps.has('rules_ack')) {
      throw new Stop(
        {
          type: 'rules',
          processTypes,
          items: this.itemViews(),
          notes: [...new Set(this.notes)],
          escalations: [...new Set(this.escalations)],
          autoAnswered: this.answers.filter((a) => a.auto).map((a) => ({ question: a.node.question_text, answer: a.label })),
        },
        5,
      );
    }
    this.askFills();
    return {
      type: 'draft',
      draft: buildDraft({
        typedName: this.input.typedName,
        items: this.draftItems(),
        vars: this.vars,
        facts: this.facts,
        processTypes,
        notes: [...new Set(this.notes)],
        escalations: [...new Set(this.escalations)],
        fills: this.fills,
      }),
    };
  }

  draftItems(): DraftItem[] {
    return this.items.map((i) => ({ item: i.item, name: i.name, role: i.role, basis: i.basis }));
  }

  /** 지금 상태의 표시 칸 (빈 칸 채우기 답 반영) */
  draftRows() {
    return buildDraft({
      typedName: this.input.typedName,
      items: this.draftItems(),
      vars: this.vars,
      facts: this.facts,
      processTypes: [],
      notes: [],
      escalations: [],
      fills: this.fills,
    }).rows;
  }

  /** 표시 칸 이름 (기록 선 툴팁용) */
  rowName(key: string): string {
    if (!this.primary) return key;
    this.rowNames ??= new Map(this.draftRows().map((r) => [r.key, r.name]));
    return this.rowNames.get(key) ?? key;
  }
  rowNames: Map<string, string> | null = null;

  /** 사용자가 직접 적을 수 있는 칸인지 (문구 블록·고정 표시·구성품 자리·발급 전 인증번호는 제외) */
  fillable(r: DraftRow): boolean {
    if (r.origin === 'text_block' || r.origin === 'fixed') return false;
    if (r.key.startsWith('component:')) return false;
    if (r.key === 'kc_mark' || r.key === 'kc_notice') return false;
    if (r.key === 'cert_no' && this.vars.cert_status !== 'done') return false;
    return true;
  }

  /** 7. 표시 초안 직전: 아직 빈 칸을 표 순서대로 하나씩 묻는다 (답하면 왼쪽 미리보기가 채워짐) */
  askFills() {
    const rows = this.draftRows();
    const targets = rows.filter((r) => this.fillable(r) && (!r.value || this.fills.has(r.key)));
    for (const [i, r] of targets.entries()) {
      if (r.value || this.fills.has(r.key)) continue;
      const ref = this.chosenCert?.rating
        ? `선택한 인증서(${this.chosenCert.certNo || this.chosenCert.modelName})의 정격: ${this.chosenCert.rating}`
        : this.facts.get('rating')?.value
          ? `자료에서 찾은 정격: ${this.facts.get('rating')!.value}`
          : null;
      throw new Stop(
        {
          type: 'fill',
          stepKey: `fill:${r.key}`,
          name: r.name,
          requirement: r.requirement,
          help: r.help,
          placeholder: r.placeholder,
          condition: r.condition,
          reference: ref,
          position: i + 1,
          total: targets.length,
        },
        6,
      );
    }
  }

  review(message: string, reasons: string[]): never {
    throw new Stop({ type: 'end', kind: 'review', title: '전문가 확인이 필요해요', message, item: this.primary ? toRef(this.primary) : null, reasons }, 2, 'escalated');
  }
}

function safeObj(s: string): Record<string, unknown> {
  try {
    const v = JSON.parse(s);
    return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
  } catch {
    return {};
  }
}

function safeArray(s: string): string[] {
  try {
    const v = JSON.parse(s);
    return Array.isArray(v) ? v.map(String) : [];
  } catch {
    return [];
  }
}
