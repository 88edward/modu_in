# 모두의 인증 — 품질 표시사항 생성

Astro(정적 페이지) + React 아일랜드 + **Cloudflare Workers**(API) + **D1**(DB).
제품 자료를 올리면 Gemini로 내용을 읽고, `src/db` 의 품목 DB 규칙으로 적용 기준을 판정해 표시 초안을 만든다.

## 처음 한 번 (로컬 개발)

```
pnpm install                         ← pnpm 없으면 먼저: npm install -g pnpm
copy .dev.vars.example .dev.vars     ← .dev.vars 를 열어 GEMINI_API_KEY 입력
pnpm db:seed:local                   ← 로컬 D1 에 src/db/*.sql 넣기
pnpm dev                             → http://localhost:4321/label/flow
```

- `pnpm dev` 는 Cloudflare 실제 런타임(workerd)과 로컬 D1(`.wrangler/state`)로 돌아간다.
- API 키가 없어도 **제품 이름만으로** 흐름 전체를 시험할 수 있다(문서 업로드만 막힘).
- SQL을 고쳤으면: `pnpm db:seed:local --reset` (표를 지우고 다시 넣음 — 세션 기록도 지워짐)

## Cloudflare 배포

```
pnpm exec wrangler login
pnpm exec wrangler d1 create modu-db  ← 출력된 database_id 를 wrangler.jsonc 에 붙여 넣기
pnpm db:seed:remote                   ← 실제 D1 에 시드 넣기
pnpm exec wrangler secret put GEMINI_API_KEY
pnpm deploy:cf                        ← 빌드 + 배포
```

패키지 관리는 **pnpm** 을 쓴다. 설치 스크립트 허용 목록(esbuild·workerd)은 `pnpm-workspace.yaml` 의 `allowBuilds`.

## 구조

```
wrangler.jsonc          Worker 이름·D1 연결·호환 날짜 (배포/로컬 공통 설정)
src/db/                 품목 DB 시드 (01~03 기존, 04 어린이제품(부록 C), 90 앱 전용 확장)
scripts/d1-seed.mjs     시드를 D1 에 넣기 (100KB 넘는 INSERT 는 자동 분할)
src/lib/server/
  d1.ts                 D1 접근
  catalog.ts            기준 데이터를 D1 에서 한 번에 읽어 메모리 캐시(5분)
  gemini.ts             문서 → 텍스트·값 추출, (애매할 때만) 품목 후보 추천
  facts.ts              추출값 → 판정 변수 (자동 응답용)
  match.ts              6개 분야 전체 품목 검색 (이름·별칭·전용 품목 우선)
  engine.ts             판정 엔진 (답을 처음부터 재생 → 항상 같은 결과)
  draft.ts              공통 틀 + 품목별 차이 병합 → 표시 초안
  session.ts            세션·업로드·추출값·답 기록 (D1)
src/pages/api/flow.ts   흐름 API
src/pages/label/flow.astro + src/components/islands/flow/   단계형 화면
```
