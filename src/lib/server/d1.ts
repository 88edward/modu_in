// Cloudflare D1 연결 (wrangler.jsonc 의 d1_databases → binding "DB")
import { env } from 'cloudflare:workers';

export function getDb(): D1Database {
  if (!env.DB) throw new Error('D1 바인딩(DB)이 없어요. wrangler.jsonc 의 d1_databases 설정을 확인하세요.');
  return env.DB;
}

export async function all<T>(sql: string, ...params: unknown[]): Promise<T[]> {
  const r = await getDb()
    .prepare(sql)
    .bind(...params)
    .all<T>();
  return r.results ?? [];
}

export async function first<T>(sql: string, ...params: unknown[]): Promise<T | null> {
  return getDb()
    .prepare(sql)
    .bind(...params)
    .first<T>();
}

export async function run(sql: string, ...params: unknown[]) {
  return getDb()
    .prepare(sql)
    .bind(...params)
    .run();
}

/** 여러 쓰기를 한 번에 (D1 batch = 하나의 트랜잭션) */
export async function batch(statements: { sql: string; params: unknown[] }[]) {
  if (!statements.length) return [];
  const db = getDb();
  return db.batch(statements.map((s) => db.prepare(s.sql).bind(...s.params)));
}
