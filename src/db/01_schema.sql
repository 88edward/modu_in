-- =====================================================================
-- 품질표시사항 가이드 챗봇 · DB 스키마 (Cloudflare D1 / SQLite)
-- 적용 순서: 01_schema.sql → 02_common_seed.sql → 03_seed_guidebook.sql → 04_seed_kids.sql
-- 용어는 docs/glossary.md, 설계 설명은 품질표시사항_분기설계.md
-- JSON 조건 형식:  {"var":"x","eq":v} | {"var":"x","in":[..]} | {"var":"x","has":v}(복수선택 값에 v 포함)
--                  {"var":"x","gt":n} | {"var":"x","gte":n} | {"var":"x","lt":n} | {"var":"x","lte":n}
--                  {"all":[..]} | {"any":[..]} | {"not":{..}}
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. 품목 (가이드북 세부품목 한 페이지 = 한 행)
-- ---------------------------------------------------------------------
CREATE TABLE items (
    id              INTEGER PRIMARY KEY,
    code            TEXT UNIQUE NOT NULL,          -- 'E-0231', 'L-0045', 'kids_leather'
    name            TEXT NOT NULL,                 -- 세부품목 이름 (사용자에게 보이는 이름)
    category        TEXT NOT NULL CHECK (category IN ('electric','living','kids','food','cosmetic','chemical')),
    group1          TEXT,                          -- 전기: 대분류 / 생활: 품목
    group2          TEXT,                          -- 전기: 중분류 / 생활: 세부품목
    cert_type       TEXT CHECK (cert_type IN ('safety_cert','safety_check','sdoc','compliance')),
    base_standard   TEXT,                          -- 적용기준 (부속서 번호, KC 규격)
    scope_text      TEXT,                          -- 적용범위 설명
    source_doc      TEXT,                          -- 근거 문서 이름
    source_page     INTEGER,
    source_url      TEXT,
    source_edition  TEXT,                          -- 예: '가이드북 2021-11'
    notice_no       TEXT,
    needs_standard_text INTEGER NOT NULL DEFAULT 0 CHECK (needs_standard_text IN (0,1)), -- 추가 표시가 KC 규격 원문에만 있음
    extraction      TEXT NOT NULL DEFAULT 'manual' CHECK (extraction IN ('auto','manual')),
    review_status   TEXT NOT NULL DEFAULT 'unreviewed' CHECK (review_status IN ('unreviewed','reviewed','needs_fix')),
    verified_at     TEXT
);
CREATE INDEX idx_items_cat ON items(category, cert_type);
CREATE INDEX idx_items_name ON items(name);

-- 검색용 별칭 (예: 커피 그라인더 → 커피분쇄기)
CREATE TABLE item_aliases (
    item_id         INTEGER NOT NULL REFERENCES items(id),
    alias           TEXT NOT NULL,
    PRIMARY KEY (item_id, alias)
);

-- ---------------------------------------------------------------------
-- 2. 변수 사전 (6개 카테고리 공통 변수명)
-- ---------------------------------------------------------------------
CREATE TABLE variables (
    name            TEXT PRIMARY KEY,
    description     TEXT NOT NULL,
    value_type      TEXT NOT NULL CHECK (value_type IN ('enum','text','number','boolean'))
);

-- ---------------------------------------------------------------------
-- 3. 질문 노드 / 선택지
--    scope: global(전 품목) | category(카테고리 전체) | item(품목 전용) | group(형제 선택) | trait(공통분모 태그)
--    엔진은 sort_order 순서로 돌며, 적용 대상이 아니거나 show_if가 거짓이면 건너뛴다.
-- ---------------------------------------------------------------------
CREATE TABLE question_nodes (
    id              INTEGER PRIMARY KEY,
    code            TEXT UNIQUE NOT NULL,
    scope           TEXT NOT NULL CHECK (scope IN ('global','category','item','group','trait')),
    category        TEXT,                          -- scope=category
    item_id         INTEGER REFERENCES items(id),  -- scope=item
    group_id        INTEGER,                       -- scope=group (item_groups.id)
    trait_code      TEXT,                          -- scope=trait
    sort_order      INTEGER NOT NULL,
    question_text   TEXT NOT NULL,
    help_text       TEXT,
    confirm_template TEXT,                         -- 업로드 자료에서 뽑은 값이 있을 때 확인형 문구
    input_type      TEXT NOT NULL CHECK (input_type IN ('single_choice','multi_choice','text','number')),
    save_as         TEXT NOT NULL REFERENCES variables(name),
    show_if         TEXT CHECK (show_if IS NULL OR json_valid(show_if))
);

CREATE TABLE question_options (
    id              INTEGER PRIMARY KEY,
    node_id         INTEGER NOT NULL REFERENCES question_nodes(id) ON DELETE CASCADE,
    sort_order      INTEGER NOT NULL,
    label           TEXT NOT NULL,
    value           TEXT NOT NULL,
    sets            TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(sets)),
    action          TEXT NOT NULL DEFAULT 'next' CHECK (action IN ('next','escalate','switch_item','wait','out_of_scope')),
    action_target   TEXT,
    action_message  TEXT
);

-- ---------------------------------------------------------------------
-- 4. 품목 적용 조건 (적용범위·인증구분을 가르는 구간)
--    예: 정격입력 1.5 kW 이하만 해당 / 직류 42 V 이하면 공급자적합성확인으로 전환
-- ---------------------------------------------------------------------
CREATE TABLE item_scope_rules (
    id              INTEGER PRIMARY KEY,
    item_id         INTEGER NOT NULL REFERENCES items(id),
    rule_code       TEXT NOT NULL,                 -- max_input, low_voltage_switch, ac_only, excl_explosion ...
    description     TEXT NOT NULL,                 -- 가이드북 문장 요약
    question_code   TEXT,                          -- 이 조건을 확인하는 질문
    fail_if         TEXT CHECK (fail_if IS NULL OR json_valid(fail_if)),  -- 참이면 아래 on_fail
    on_fail         TEXT NOT NULL CHECK (on_fail IN ('out_of_scope','switch_cert','switch_item','escalate','note')),
    target_cert     TEXT,                          -- switch_cert 일 때
    target_item     TEXT,                          -- switch_item 일 때 (items.code)
    verified        INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0,1))
);

-- ---------------------------------------------------------------------
-- 5. 라벨: 공통 뼈대(템플릿) + 품목별 추가 항목
-- ---------------------------------------------------------------------
CREATE TABLE label_templates (
    code            TEXT PRIMARY KEY,              -- 'electric_base', 'living_base', 'kids_base'
    category        TEXT NOT NULL,
    description     TEXT
);

CREATE TABLE label_fields (
    id              INTEGER PRIMARY KEY,
    template_code   TEXT REFERENCES label_templates(code),
    item_id         INTEGER REFERENCES items(id),
    sort_order      INTEGER NOT NULL,
    field_key       TEXT NOT NULL,
    display_name    TEXT NOT NULL,
    requirement     TEXT NOT NULL CHECK (requirement IN ('required','recommended','conditional')),
    show_if         TEXT CHECK (show_if IS NULL OR json_valid(show_if)),
    source          TEXT NOT NULL CHECK (source IN ('answer','form','fixed','text_block')),
    source_key      TEXT,
    form_help       TEXT,
    placeholder_text TEXT,
    condition_text  TEXT,                          -- 가이드북 원문 조건 (예: '팽창식인 경우')
    CHECK ((template_code IS NULL) <> (item_id IS NULL))
);
CREATE INDEX idx_label_item ON label_fields(item_id);

CREATE TABLE item_templates (
    item_id         INTEGER PRIMARY KEY REFERENCES items(id),
    template_code   TEXT NOT NULL REFERENCES label_templates(code)
);

-- 주의사항, 안전기준 표시사항, 표시 방법 등 문구 묶음
CREATE TABLE text_blocks (
    id              INTEGER PRIMARY KEY,
    item_id         INTEGER REFERENCES items(id),
    code            TEXT NOT NULL,                 -- 'care' | 'caution' | 'std_marks' | 'display_method'
    variant         TEXT NOT NULL DEFAULT 'default',
    show_if         TEXT CHECK (show_if IS NULL OR json_valid(show_if)),
    title           TEXT,
    lines           TEXT NOT NULL CHECK (json_valid(lines)),
    needs_review    INTEGER NOT NULL DEFAULT 0 CHECK (needs_review IN (0,1))
);
CREATE INDEX idx_text_item ON text_blocks(item_id);

-- ---------------------------------------------------------------------
-- 6. 품목 간 관계
-- ---------------------------------------------------------------------
CREATE TABLE item_relations (
    id              INTEGER PRIMARY KEY,
    item_id         INTEGER NOT NULL REFERENCES items(id),
    related_item_id INTEGER NOT NULL REFERENCES items(id),
    relation        TEXT NOT NULL CHECK (relation IN ('exclusive','parallel','component')),
    trigger_if      TEXT CHECK (trigger_if IS NULL OR json_valid(trigger_if)),
    basis           TEXT,
    verified        INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0,1))
);

-- kind: siblings(형제 세부품목 카드) | cert_split(같은 제품이 조건에 따라 인증구분이 갈림) | age_class(연령 등급)
CREATE TABLE item_groups (
    id              INTEGER PRIMARY KEY,
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    kind            TEXT NOT NULL CHECK (kind IN ('siblings','cert_split','age_class')),
    selector_node   TEXT                           -- 고르는 질문 code
);

CREATE TABLE item_group_members (
    group_id        INTEGER NOT NULL REFERENCES item_groups(id),
    item_id         INTEGER NOT NULL REFERENCES items(id),
    select_if       TEXT CHECK (select_if IS NULL OR json_valid(select_if)),  -- NULL = 카드로 직접 고름
    card_summary    TEXT,                          -- "라벨에 더 들어가는 것"
    PRIMARY KEY (group_id, item_id)
);

CREATE TABLE field_merge_rules (
    field_key       TEXT PRIMARY KEY,
    merge_mode      TEXT NOT NULL CHECK (merge_mode IN ('dedupe','list','strictest')),
    note            TEXT
);

-- ---------------------------------------------------------------------
-- 7. 공통분모 태그
-- ---------------------------------------------------------------------
CREATE TABLE traits (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    description     TEXT
);

CREATE TABLE item_traits (
    item_id         INTEGER NOT NULL REFERENCES items(id),
    trait_code      TEXT NOT NULL REFERENCES traits(code),
    applies_if      TEXT CHECK (applies_if IS NULL OR json_valid(applies_if)),
    question_override TEXT,
    example_hint    TEXT,
    source          TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('auto','manual')),
    PRIMARY KEY (item_id, trait_code)
);

CREATE TABLE trait_outcomes (
    id              INTEGER PRIMARY KEY,
    trait_code      TEXT NOT NULL REFERENCES traits(code),
    answer_value    TEXT NOT NULL,
    outcome         TEXT NOT NULL CHECK (outcome IN ('add_item','cross_check','escalate','none')),
    target          TEXT,
    relation        TEXT CHECK (relation IN ('parallel','component')),
    basis           TEXT,
    verified        INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0,1))
);

-- ---------------------------------------------------------------------
-- 8. 인증 구분 안내 / 자료 우선순위
-- ---------------------------------------------------------------------
CREATE TABLE cert_guidance (
    cert_type       TEXT PRIMARY KEY CHECK (cert_type IN ('safety_cert','safety_check','sdoc','compliance')),
    display_name    TEXT NOT NULL,
    summary         TEXT NOT NULL,
    has_kc_mark     INTEGER NOT NULL CHECK (has_kc_mark IN (0,1)),
    has_cert_no     INTEGER NOT NULL CHECK (has_cert_no IN (0,1)),
    reference_url   TEXT,
    verified        INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0,1))
);

CREATE TABLE source_priority (
    kind            TEXT PRIMARY KEY,
    priority        INTEGER NOT NULL
);

-- 전기 가이드북 부록: KC 규격별 공통 표시 요구사항 (461~499쪽)
CREATE TABLE standard_refs (
    code            TEXT PRIMARY KEY,              -- 'KC 60335-1'
    title           TEXT,
    source_page     INTEGER,
    excerpt         TEXT
);

-- ---------------------------------------------------------------------
-- 9. 세션
-- ---------------------------------------------------------------------
CREATE TABLE chat_sessions (
    id              TEXT PRIMARY KEY,
    vars            TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(vars)),
    status          TEXT NOT NULL DEFAULT 'in_progress'
                      CHECK (status IN ('in_progress','done','escalated','waiting','out_of_scope')),
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE session_items (
    session_id      TEXT NOT NULL REFERENCES chat_sessions(id),
    item_id         INTEGER NOT NULL REFERENCES items(id),
    role            TEXT NOT NULL CHECK (role IN ('primary','parallel','component')),
    added_by        TEXT,
    PRIMARY KEY (session_id, item_id)
);

CREATE TABLE chat_answers (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES chat_sessions(id),
    node_id         INTEGER NOT NULL REFERENCES question_nodes(id),
    value           TEXT,
    auto_filled     INTEGER NOT NULL DEFAULT 0 CHECK (auto_filled IN (0,1)),
    answered_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE session_uploads (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES chat_sessions(id),
    kind            TEXT NOT NULL CHECK (kind IN ('product_name','photo','manual','certificate')),
    r2_key          TEXT,
    text_value      TEXT,
    uploaded_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE extracted_facts (
    id              INTEGER PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES chat_sessions(id),
    variable        TEXT NOT NULL REFERENCES variables(name),
    value           TEXT NOT NULL,
    upload_id       INTEGER REFERENCES session_uploads(id),
    method          TEXT NOT NULL CHECK (method IN ('regex','ocr','ai')),
    model           TEXT,
    confidence      REAL CHECK (confidence BETWEEN 0 AND 1),
    evidence        TEXT,
    status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','rejected','conflict'))
);
