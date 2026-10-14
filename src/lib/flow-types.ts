// 표시사항 생성 흐름: 서버(API)와 화면(React)이 함께 쓰는 타입

export type Category = 'electric' | 'living' | 'kids' | 'food' | 'cosmetic' | 'chemical';
export type CertType = 'safety_cert' | 'safety_check' | 'sdoc' | 'compliance';
export type ItemRole = 'primary' | 'parallel' | 'component';

export const CATEGORY_LABEL: Record<Category, string> = {
  electric: '전기용품',
  living: '생활용품',
  kids: '어린이제품',
  food: '식품용 기구·용기',
  cosmetic: '화장품',
  chemical: '생활화학제품',
};

export const CERT_LABEL: Record<CertType, string> = {
  safety_cert: '안전인증',
  safety_check: '안전확인',
  sdoc: '공급자적합성확인',
  compliance: '안전기준준수',
};

/** 서비스 흐름 7단계 (진행 막대) */
export const FLOW_STEPS = [
  '파일 업로드',
  '문서 내용 추출',
  '전체 품목 매칭',
  '구분 질문',
  '최신 원문 확인',
  '추가 규칙 적용',
  '표시 초안 생성',
] as const;

export interface ItemRef {
  code: string;
  name: string;
  category: Category;
  certType: CertType | null;
  group?: string | null;
}

export interface FactView {
  key: string;
  label: string;
  value: string;
  evidence?: string | null;
  source?: string | null;
  confidence?: number | null;
  conflict?: string[]; // 다른 자료에서 다르게 나온 값
}

export interface Option {
  value: string;
  label: string;
  hint?: string;
  badge?: string;
}

export interface SourceView {
  item: ItemRef;
  role: ItemRole;
  doc: string | null;
  page: number | null;
  edition: string | null;
  url: string | null;
  standard: string | null;
  verifiedAt: string | null;
  flags: string[];
}

export interface SessionItemView {
  item: ItemRef | null; // null = DB에 품목이 없는 구성품(별도 판정 필요)
  name: string;
  role: ItemRole;
  basis: string;
}

export type ProcessType = 'single' | 'main_plus' | 'component' | 'parallel' | 'review';

export const PROCESS_TYPE_INFO: Record<ProcessType, { title: string; desc: string }> = {
  single: { title: '단일 규정', desc: '전용 품목 기준 하나가 완제품 전체를 다 다뤄요.' },
  main_plus: { title: '주 규정 + 조건', desc: '주 품목에 특정 조건(무선 등)이 붙으면 추가 의무가 붙어요.' },
  component: { title: '구성품별 규정', desc: '본체·충전기·배터리·리필을 각각 따로 봐요.' },
  parallel: { title: '위험별 병행', desc: '서로 다른 위험을 각 법이 따로 관리해요.' },
  review: { title: '사람 검토', desc: '품목 범위·제외 규정만으로 결론이 안 나서 확인이 필요해요.' },
};

export interface DraftRow {
  key: string;
  name: string;
  requirement: 'required' | 'recommended' | 'conditional';
  value: string;
  placeholder: string | null;
  help: string | null;
  condition: string | null;
  multiline: boolean;
  origin: 'document' | 'fixed' | 'answer' | 'text_block' | 'empty';
  location: string;
  sources: { code: string; name: string; basis: string }[];
  needsReview: boolean;
}

export interface Draft {
  productName: string;
  processTypes: ProcessType[];
  certSummary: { item: ItemRef; certType: CertType; label: string; summary: string; kcMark: boolean; certNo: boolean }[];
  items: SessionItemView[];
  rows: DraftRow[];
  displayMethods: { item: string; lines: string[] }[];
  unresolved: string[];
  notes: string[];
}

export type Screen =
  | {
      type: 'facts';
      productName: string;
      docs: { name: string; kind: string; chars: number }[];
      facts: FactView[];
      warnings: string[];
    }
  | {
      type: 'question';
      stepKey: string;
      title: string;
      help?: string | null;
      note?: string | null;
      input: 'single_choice' | 'multi_choice' | 'number' | 'text';
      options: Option[];
      defaultValue?: string | string[] | null;
      unit?: string;
    }
  | { type: 'wait'; stepKey: string; title: string; message: string }
  | { type: 'no_match'; tried: string[]; message: string }
  | { type: 'end'; kind: 'out_of_scope' | 'review'; title: string; message: string; item?: ItemRef | null; reasons: string[] }
  | { type: 'source_check'; sources: SourceView[] }
  | {
      type: 'rules';
      processTypes: ProcessType[];
      items: SessionItemView[];
      notes: string[];
      escalations: string[];
      autoAnswered: { question: string; answer: string }[];
    }
  | {
      /** 표시 초안 직전: 아직 빈 칸 하나를 채운다 ('' = 나중에 채우기) */
      type: 'fill';
      stepKey: string;
      name: string;
      requirement: 'required' | 'recommended' | 'conditional';
      help: string | null;
      placeholder: string | null;
      condition: string | null;
      reference: string | null; // 참고용 자료 내용 (예: 선택한 인증서의 정격)
      position: number;
      total: number;
    }
  | { type: 'draft'; draft: Draft };

/** 지금까지 한 답 하나 (위쪽 기록 선 한 칸). index 번째 답으로 돌아가면 그 답부터 다시 묻는다 */
export interface HistoryStep {
  index: number;
  title: string; // 접근성·툴팁용 (선 안에는 글자를 넣지 않음)
  answer: string;
  stage: number; // FLOW_STEPS index
}

/** 왼쪽 표시사항 미리보기 — 답할 때마다 칸이 채워진다 */
export interface PreviewRow {
  key: string;
  name: string;
  value: string;
  placeholder: string | null;
  requirement: 'required' | 'recommended' | 'conditional';
  origin: DraftRow['origin'];
  multiline: boolean;
}

export interface Preview {
  title: string; // 판정 중인 품목 (없으면 '품목 판정 전')
  subtitle: string | null; // 분야 · 인증 구분
  rows: PreviewRow[];
}

/** 트리 보기: 품목표(분야 → 대분류 → 중분류 → 품목) + 판정 결정 */
export interface TreeNode {
  id: string;
  label: string;
  sub?: string | null;
  kind: 'root' | 'category' | 'group' | 'item' | 'decision' | 'hidden';
  /** path = 지금 내가 있는 경로, candidate = 후보, idle = 아직 안 가른 가지, muted = 선택되지 않은 분기 */
  state: 'path' | 'candidate' | 'idle' | 'muted';
  edge?: string | null; // 이 노드로 오게 한 질문·답
  count?: number | null;
  children?: TreeNode[];
}

export interface TrailStep {
  label: string;
  detail: string;
}

export interface FlowResponse {
  sessionId: string;
  screen: Screen;
  progress: number; // FLOW_STEPS index
  notice?: string | null; // 일부 파일 읽기 실패 등 안내
  history: HistoryStep[];
  preview: Preview | null;
  tree: TreeNode;
  trail: TrailStep[];
}

/** '이전'을 눌렀는데 더 돌아갈 단계가 없으면 업로드 화면으로 */
export type FlowReply = FlowResponse | { restart: true } | { error: string };
