-- =====================================================================
-- 90_app_extension.sql : 웹 서비스(표시사항 생성 흐름)용 확장
--   * 기존 01~04 파일은 수정하지 않고, 앱이 쓰는 것만 여기서 추가한다.
--   * 적용 순서: 01 → 02 → 03 → (04) → 90
-- =====================================================================
PRAGMA foreign_keys = ON;

-- 업로드 문서에서 뽑는 값(라벨 입력칸·판정 단서) — extracted_facts.variable FK 용
INSERT OR IGNORE INTO variables (name, description, value_type) VALUES
('product_name', '제품명 (자료 표기)', 'text'),
('generic_names', '일반 품목명 후보 (쉼표 구분, 품목표 검색어)', 'text'),
('main_function', '주된 기능 (사람들이 무엇 때문에 사는지)', 'text'),
('model_name', '모델명', 'text'),
('maker', '제조자명', 'text'),
('importer', '수입자명', 'text'),
('country', '제조국', 'text'),
('address_phone', '주소 및 전화번호', 'text'),
('as_contact', 'A/S 연락처', 'text'),
('rating', '정격 표기 원문 (예: AC 220 V 60 Hz 45 W)', 'text'),
('voltage_type', '전원 종류: AC|DC|AC/DC', 'enum'),
('voltage_v', '입력 전압(V)', 'number'),
('power_w', '소비전력(W)', 'number'),
('frequency_hz', '주파수(Hz)', 'number'),
('cert_no', '인증·신고번호', 'text'),
('cert_type_text', '자료에 적힌 인증 구분 원문', 'text'),
('battery', '배터리: none|rechargeable|dry_cell', 'enum'),
('min_age', '사용 가능 최소 연령(세)', 'number'),
('max_age', '사용 가능 최대 연령(세)', 'number'),
('mfg_date', '제조연월', 'text'),
('material_note', '주요 재질 (자료 표기)', 'text');

-- 판정 재생(replay)용 단계 기록: 사용자의 답을 순서대로 쌓고,
-- 엔진은 매번 처음부터 다시 계산한다 → 누가 처리해도 같은 결과, '이전'은 마지막 기록 삭제.
CREATE TABLE IF NOT EXISTS session_steps (
    session_id      TEXT NOT NULL REFERENCES chat_sessions(id),
    seq             INTEGER NOT NULL,
    step_key        TEXT NOT NULL,                 -- 질문 code | 'facts_ok' | 'search' | 'pick' | 'wait:<code>' | 'source_ack' | 'rules_ack' | 'ai_candidates'
    value           TEXT NOT NULL,
    is_system       INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0,1)),  -- 1 = 서버가 넣은 기록(AI 후보 등), '이전' 시 함께 제거
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (session_id, seq)
);

-- DB 빌드 정보 (시드 파일이 바뀌면 자동 재빌드 판단용)
CREATE TABLE IF NOT EXISTS app_meta (
    key             TEXT PRIMARY KEY,
    value           TEXT NOT NULL
);
