// 전체 품목 검색: 처음부터 분야를 좁히지 않고 품목표(items + item_aliases) 전체를 찾는다.
// 점수 원칙 — "전용 품목 우선": 이름이 정확히 같을수록, 검색어와 겹치는 부분이 길수록 높다.
import { cat, type Catalog, type ItemRow } from './catalog';
import type { Category } from '../flow-types';

export type { ItemRow };

export interface Candidate {
  item: ItemRow;
  score: number;
  reason: string;
  /** 후보가 하나뿐일 때 묻지 않고 확정해도 되는 근거인지 */
  strong: boolean;
}

interface Indexed {
  item: ItemRow;
  names: string[]; // 정규화된 이름 + 별칭
  groups: string[];
}

export const norm = (s: string) =>
  s
    .replace(/\([^)]*\)/g, '')
    .replace(/[\s·・\-_/,.()[\]]/g, '')
    .toLowerCase();

// 검색 색인은 기준 데이터(catalog)가 새로 로드될 때마다 다시 만든다
const indexCache = new WeakMap<Catalog, Indexed[]>();

function load() {
  const c = cat();
  let index = indexCache.get(c);
  if (!index) {
    index = c.items.map((item) => ({
      item,
      names: [...new Set([norm(item.name), ...(c.aliasesByItem.get(item.id) ?? []).map(norm)])].filter((n) => n.length >= 2),
      groups: [...new Set([item.group1, item.group2].filter(Boolean).map((g) => norm(g!)))].filter((g) => g.length >= 2),
    }));
    indexCache.set(c, index);
  }
  return { items: c.itemByCode, byId: c.itemById, index };
}

export const itemByCode = (code: string) => load().items.get(code);
export const itemById = (id: number) => load().byId.get(id);
export const catalogue = () =>
  load().index.map(({ item }) => ({ code: item.code, name: item.name, category: item.category, group: item.group2 }));

/** 너무 흔한 검색어(예: "전기")가 수백 개를 끌고 오지 않도록, 부분일치가 이보다 많으면 그 검색어의 부분일치는 버린다 */
const MAX_PARTIAL_HITS = 15;

/**
 * 겉모습·수식어 — 판단에 참고하는 단서일 뿐 품목을 정하지 않는다.
 * ("전동", "어린이용", "무선"이 붙었다고 그 분야 규정을 무조건 더하지 않음)
 */
const MODIFIERS = new Set(
  ['어린이', '어린이용', '유아', '유아용', '아동', '아동용', '키즈', '전동', '무선', '유선', '휴대용', '미니', '충전식', '가정용', '업소용', '전기', '전자', '블루투스', 'usb', '스마트', '자동', '소형', '대형', '접이식', '탁상용', '캐릭터', '신형', '프리미엄'].map(norm),
);

/** 단어 단위 검색에서 나온 후보의 최고 점수 (이보다 낮으면 AI 추천을 함께 본다) */
export const WORD_MATCH_CAP = 65;

/** 검색어에서 수식어를 뺀 핵심어 (예: "전동 비비탄총" → "비비탄총") */
export function coreTerms(terms: string[]): string[] {
  const out = new Set<string>();
  for (const raw of terms) {
    out.add(norm(raw));
    const words = raw.split(/\s+/).filter((w) => norm(w).length >= 2 && !MODIFIERS.has(norm(w)));
    if (words.length) out.add(norm(words.join('')));
  }
  return [...out];
}

export function searchItems(terms: string[], opts: { category?: Category; limit?: number } = {}): Candidate[] {
  const { index } = load();
  const best = new Map<string, Candidate>();
  const offer = (item: ItemRow, score: number, reason: string, strong: boolean) => {
    if (item.name.includes('기타')) score -= 10; // 포괄 품목은 전용 품목보다 뒤로
    const prev = best.get(item.code);
    if (!prev || prev.score < score) best.set(item.code, { item, score: Math.round(score * 10) / 10, reason, strong });
  };

  // 검색어 전체 + (여러 단어면) 수식어를 뺀 단어 각각. 단어 단위 일치는 점수 상한을 둔다.
  const queries: { raw: string; cap: number }[] = [];
  for (const raw of terms) {
    queries.push({ raw, cap: 100 });
    const words = raw.split(/\s+/).filter((w) => norm(w).length >= 2 && !MODIFIERS.has(norm(w)));
    if (raw.trim().split(/\s+/).length > 1) {
      // 수식어를 빼고 남은 핵심어가 하나면 그게 제품 자체(예: 전동 비비탄총 → 비비탄총),
      // 여럿이면 각 단어는 단서 수준이라 점수 상한을 둔다
      if (words.length === 1) queries.push({ raw: words[0], cap: 100 });
      else if (words.length > 1) {
        queries.push({ raw: words.join(' '), cap: 100 });
        for (const w of words) queries.push({ raw: w, cap: WORD_MATCH_CAP });
      }
    }
  }

  for (const { raw, cap } of queries) {
    const t = norm(raw);
    if (t.length < 2) continue;
    const partial: [ItemRow, number, string, boolean][] = [];
    // strong: 그대로 확정해도 되는 근거 (이름 일치, 또는 제품명이 품목명을 통째로 품음)
    const offerCapped = (item: ItemRow, score: number, reason: string, strong: boolean) => offer(item, Math.min(score, cap), reason, strong && cap === 100);

    for (const { item, names, groups } of index) {
      if (opts.category && item.category !== opts.category) continue;
      let hit = false;
      for (const n of names) {
        if (n === t) {
          offerCapped(item, n === norm(item.name) ? 100 : 95, `'${raw}'와 이름 일치`, true);
          hit = true;
        } else if (t.includes(n)) {
          // 검색어가 품목명을 품음 (예: 탁상용선풍기 ⊃ 선풍기)
          partial.push([item, 60 + (35 * n.length) / t.length, `'${raw}' 안에 품목명 '${item.name}' 포함`, true]);
        } else if (n.includes(t)) {
          // 품목명이 검색어를 품음 (예: 전기밥솥 ⊃ 밥솥 / 샴푸기기 ⊃ 샴푸) — 다른 제품일 수 있어 확인 필요
          partial.push([item, 55 + (35 * t.length) / n.length, `품목명 '${item.name}'에 '${raw}' 포함`, false]);
        }
      }
      if (!hit && groups.some((g) => g === t)) offerCapped(item, 50, `분류 '${item.group2 ?? item.group1}'와 일치`, false);
    }

    const distinct = new Set(partial.map(([i]) => i.code));
    if (distinct.size <= MAX_PARTIAL_HITS) for (const [i, s, r, st] of partial) offerCapped(i, s, r, st);
  }

  return [...best.values()].sort((a, b) => b.score - a.score || a.item.code.localeCompare(b.item.code)).slice(0, opts.limit ?? 12);
}

/** 후보 중 1순위 묶음: 정확히 일치하는 게 있으면 그것들만, 아니면 최고점에 가까운 것들 */
export function topTier(cands: Candidate[]): Candidate[] {
  if (!cands.length) return [];
  const best = cands[0].score;
  const cut = best >= 95 ? 95 : best - 8;
  return cands.filter((c) => c.score >= cut).slice(0, 8);
}
