// DB의 JSON 조건식 평가 (01_schema.sql 상단 형식)
//   {"var":"x","eq":v} | {"var":"x","in":[..]} | {"var":"x","has":v}
//   {"var":"x","gt":n} | gte | lt | lte
//   {"all":[..]} | {"any":[..]} | {"not":{..}}
// 변수가 아직 없으면 비교식은 거짓 → "확인되지 않은 조건으로는 결론을 내지 않는다".

export type Vars = Record<string, unknown>;

type Cond =
  | { all: Cond[] }
  | { any: Cond[] }
  | { not: Cond }
  | { var: string; eq?: unknown; in?: unknown[]; has?: unknown; gt?: number; gte?: number; lt?: number; lte?: number };

export function parseCond(json: string | null | undefined): Cond | null {
  if (!json) return null;
  try {
    return JSON.parse(json) as Cond;
  } catch {
    return null;
  }
}

const same = (a: unknown, b: unknown) => a === b || String(a) === String(b);

export function evalCond(cond: Cond | string | null | undefined, vars: Vars): boolean {
  const c = typeof cond === 'string' ? parseCond(cond) : cond;
  if (!c) return true;
  if ('all' in c) return c.all.every((x) => evalCond(x, vars));
  if ('any' in c) return c.any.some((x) => evalCond(x, vars));
  if ('not' in c) return !evalCond(c.not, vars);

  const v = vars[c.var];
  if (v === undefined || v === null || v === '') return false;
  if ('eq' in c) return same(v, c.eq);
  if ('in' in c && Array.isArray(c.in)) return c.in.some((x) => same(v, x));
  if ('has' in c) return Array.isArray(v) && v.some((x) => same(x, c.has));
  const n = Number(v);
  if (Number.isNaN(n)) return false;
  if (c.gt !== undefined) return n > c.gt;
  if (c.gte !== undefined) return n >= c.gte;
  if (c.lt !== undefined) return n < c.lt;
  if (c.lte !== undefined) return n <= c.lte;
  return false;
}

/** 조건이 참조하는 변수 이름들 */
export function condVars(cond: Cond | string | null | undefined, out = new Set<string>()): Set<string> {
  const c = typeof cond === 'string' ? parseCond(cond) : cond;
  if (!c) return out;
  if ('all' in c) c.all.forEach((x) => condVars(x, out));
  else if ('any' in c) c.any.forEach((x) => condVars(x, out));
  else if ('not' in c) condVars(c.not, out);
  else out.add(c.var);
  return out;
}
