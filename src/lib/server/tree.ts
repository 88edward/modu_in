// 트리 보기: 품목표(루트 → 분야 → 대분류 → 중분류 → 품목) 위에 지금까지의 판정을 겹쳐 보여준다.
// 화면이 복잡해지지 않도록, 지금 경로(또는 후보)가 있는 가지만 펼치고 나머지는 "다른 … N개" 블록 하나로 접는다.
//  - 품목이 정해지기 전: 후보가 있는 분야·분류만 펼침
//  - 품목이 정해진 뒤: 그 품목으로 가는 경로 하나만 남기고, 아래에 판정 분기(인증구분 전환·구성품·병행)를 붙인다
import { cat, type ItemRow } from './catalog';
import { CATEGORY_LABEL, CERT_LABEL, type Category, type CertType, type ItemRole, type TreeNode } from '../flow-types';

const CATEGORY_ORDER: Category[] = ['electric', 'living', 'kids', 'food', 'cosmetic', 'chemical'];
const ROLE_LABEL: Record<ItemRole, string> = { primary: '주 품목', parallel: '병행 기준', component: '구성품' };

export interface TreeInput {
  candidates: ItemRow[];
  primary: ItemRow | null;
  primaryCert: CertType | null;
  via: string | null;
  decisions: { label: string; sub: string }[];
  related: { item: ItemRow | null; name: string; role: ItemRole; basis: string }[];
}

const clean = (s: string | null | undefined) => (s ?? '').replace(/\s+/g, ' ').trim();

export function buildTree(input: TreeInput): TreeNode {
  const c = cat();
  const focus = input.primary ? [input.primary] : input.candidates;
  const focusCodes = new Set(focus.map((i) => i.code));
  const byCategory = new Map<Category, ItemRow[]>();
  for (const it of c.items) byCategory.set(it.category, [...(byCategory.get(it.category) ?? []), it]);

  const catNode = (category: Category, state: TreeNode['state'], children?: TreeNode[]): TreeNode => {
    const n = byCategory.get(category)?.length ?? 0;
    return {
      id: `cat:${category}`,
      label: CATEGORY_LABEL[category],
      sub: n ? `${n}개 품목` : '준비 중',
      kind: 'category',
      state: n ? state : 'muted',
      count: n,
      children,
    };
  };

  // 아직 검색 전: 분야만
  if (!focus.length) {
    return {
      id: 'root',
      label: '품목표 전체',
      sub: `${c.items.length}개 품목 · 6개 분야`,
      kind: 'root',
      state: 'idle',
      children: CATEGORY_ORDER.map((k) => catNode(k, 'idle')),
    };
  }

  const focusCats = CATEGORY_ORDER.filter((k) => focus.some((i) => i.category === k));
  const decided = Boolean(input.primary);
  const children: TreeNode[] = focusCats.map((k) => catNode(k, decided || focusCats.length === 1 ? 'path' : 'candidate', groupLevel(k)));
  const others = CATEGORY_ORDER.filter((k) => !focusCats.includes(k));
  if (others.length) children.push(hidden('cat-others', `다른 분야 ${others.length}개`, others.map((k) => CATEGORY_LABEL[k]).join(' · ')));

  return {
    id: 'root',
    label: '품목표 전체',
    sub: `${c.items.length}개 품목 · 6개 분야`,
    kind: 'root',
    state: 'path',
    children,
  };

  // ---------------------------------------------------------------- 분류 단계

  function groupLevel(category: Category): TreeNode[] {
    const all = byCategory.get(category) ?? [];
    const mine = focus.filter((i) => i.category === category);
    const g1s = [...new Set(mine.map((i) => clean(i.group1) || '기타'))];
    const allG1 = new Set(all.map((i) => clean(i.group1) || '기타'));
    const out: TreeNode[] = [];

    for (const g1 of g1s) {
      const inG1 = mine.filter((i) => (clean(i.group1) || '기타') === g1);
      const sub = subLevel(all.filter((i) => (clean(i.group1) || '기타') === g1), inG1, g1);
      // 대분류 이름이 분야 이름과 같거나, 품목 하나뿐인데 그 품목 이름이면 단계를 건너뛴다 (예: 생활용품 "우산 및 양산")
      if (g1 === CATEGORY_LABEL[category] || (inG1.length === 1 && g1 === clean(inG1[0].name))) out.push(...sub);
      else out.push(groupNode(`g1:${category}:${g1}`, g1, all.filter((i) => (clean(i.group1) || '기타') === g1).length, sub));
    }
    const rest = allG1.size - g1s.length;
    if (rest > 0) out.push(hidden(`g1-others:${category}`, `다른 대분류 ${rest}개`, null));
    return out;
  }

  function subLevel(allInG1: ItemRow[], mineInG1: ItemRow[], g1: string): TreeNode[] {
    const g2s = [...new Set(mineInG1.map((i) => clean(i.group2) || g1))];
    const allG2 = new Set(allInG1.map((i) => clean(i.group2) || g1));
    const out: TreeNode[] = [];
    for (const g2 of g2s) {
      const allInG2 = allInG1.filter((i) => (clean(i.group2) || g1) === g2);
      const mine = mineInG1.filter((i) => (clean(i.group2) || g1) === g2);
      const leaves: TreeNode[] = mine.map(itemNode);
      const rest = allInG2.length - mine.length;
      if (rest > 0 && decided) leaves.push(hidden(`items-others:${g2}`, `같은 분류 다른 품목 ${rest}개`, null));
      if (g2 === g1 || (mine.length === 1 && g2 === clean(mine[0].name))) out.push(...leaves);
      else out.push(groupNode(`g2:${g1}:${g2}`, g2, allInG2.length, leaves));
    }
    const rest = allG2.size - g2s.length;
    if (rest > 0) out.push(hidden(`g2-others:${g1}`, `다른 중분류 ${rest}개`, null));
    return out;
  }

  function groupNode(id: string, label: string, count: number, kids: TreeNode[]): TreeNode {
    return { id, label, sub: `${count}개 품목`, kind: 'group', state: decided ? 'path' : 'candidate', count, children: kids };
  }

  // ---------------------------------------------------------------- 품목(리프)과 그 아래 판정 분기

  function itemNode(it: ItemRow): TreeNode {
    const isPrimary = input.primary?.code === it.code;
    const cert = isPrimary ? (input.primaryCert ?? it.cert_type) : it.cert_type;
    const node: TreeNode = {
      id: `item:${it.code}`,
      label: it.name,
      sub: [it.code, cert ? CERT_LABEL[cert] : null].filter(Boolean).join(' · '),
      kind: 'item',
      state: isPrimary ? 'path' : focusCodes.has(it.code) ? 'candidate' : 'idle',
      edge: isPrimary ? input.via : null,
    };
    if (!isPrimary) return node;

    // 품목 확정 뒤의 분기를 사슬로 이어 붙인다: 품목 → 인증구분 전환 → … → 구성품·병행
    let tail = node;
    for (const [i, d] of input.decisions.entries()) {
      const child: TreeNode = { id: `dec:${i}`, label: d.label, sub: d.sub, kind: 'decision', state: 'path' };
      tail.children = [child];
      tail = child;
    }
    const related = input.related.map((r, i) => ({
      id: `rel:${i}`,
      label: r.name,
      sub: [ROLE_LABEL[r.role], r.item ? CATEGORY_LABEL[r.item.category] : '별도 판정 필요'].join(' · '),
      kind: 'item' as const,
      state: 'path' as const,
      edge: r.basis.length > 40 ? `${r.basis.slice(0, 40)}…` : r.basis,
    }));
    if (related.length) tail.children = related;
    return node;
  }
}

function hidden(id: string, label: string, sub: string | null): TreeNode {
  return { id, label, sub, kind: 'hidden', state: 'muted' };
}
