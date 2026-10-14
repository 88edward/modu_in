-- 02_common_seed.sql : 변수 사전, 인증 안내, 병합 규칙, 라벨 뼈대, 공통·카테고리·태그 질문
PRAGMA foreign_keys = ON;


INSERT INTO variables (name, description, value_type) VALUES
('cert_status', '인증 진행 상태: done|in_progress|not_yet|unknown', 'enum'),
('cert_type', '결정된 인증 구분 (엔진이 품목에서 세팅)', 'enum'),
('category', '결정된 카테고리', 'enum'),
('is_import', '수입품 여부', 'boolean'),
('origin', '국산/수입', 'enum'),
('bundle', '묶음 판매 여부', 'enum'),
('label_on_package', '포장 표면 표시 허용', 'boolean'),
('subitem', '형제 세부품목 선택 결과(품목 code)', 'text'),
('age_group', '사용연령 구간', 'enum'),
('bb_class', '비비탄총 연령 등급', 'enum'),
('furniture_tall_drawer', '높이 762 mm 이상 가정용 서랍장·파일링캐비닛 여부', 'enum'),
('power_type', '전원: ac_plug|rechargeable|dry_cell|none', 'enum'),
('power_source', '전기용품 전원 방식: ac|dc', 'enum'),
('is_low_voltage', '교류 30 V·직류 42 V 이하 여부', 'enum'),
('rated_input_kw', '정격입력(kW)', 'number'),
('rated_kva', '정격용량(kVA)', 'number'),
('rated_hz', '정격주파수(Hz)', 'number'),
('is_explosion_proof', '방폭형 여부', 'enum'),
('is_machine_part', '기계·기구에 부착되는 특수구조 여부', 'enum'),
('is_data_only', '통신·데이터 전송 전용 여부', 'enum'),
('has_wireless', '무선 기능', 'enum'),
('has_magnet', '떨어질 수 있는 자석 포함', 'enum'),
('food_contact', '음식 접촉', 'enum'),
('mouth_contact', '입에 넣는 제품', 'enum'),
('water_contact', '물 접촉', 'enum'),
('charger_included', '충전기 동봉', 'enum'),
('catch_all', '마지막 확인(복수 선택)', 'text'),
('cross_check', '교차 확인 카테고리', 'text'),
('show_cert_no', '인증번호 칸 표시', 'boolean'),
('form', '제품 형태', 'enum'),
('material', '겉감 소재 대분류', 'enum'),
('leather_base', '천연/인조', 'enum'),
('material_text', '라벨용 재료 표기', 'text'),
('animal', '동물명', 'text'),
('synthetic_type', '인조가죽 세부', 'enum'),
('leather_part', '의류 가죽 비중', 'enum'),
('lining', '안감', 'text'),
('lining_custom', '안감 직접 입력', 'boolean'),
('sole', '밑창 소재', 'text'),
('has_weight_limit', '크기·체중 제한', 'enum'),
('care_needs_review', '주의사항 원문 미확보', 'boolean');

INSERT INTO cert_guidance (cert_type, display_name, summary, has_kc_mark, has_cert_no) VALUES
('safety_cert', '안전인증', '출시 전에 인증기관의 시험과 공장 심사를 거쳐 인증을 받아야 해요. 라벨에 KC마크와 인증번호가 들어가요.', 1, 1),
('safety_check', '안전확인', '출시 전에 시험을 받고 신고해야 해요. 라벨에 KC마크와 신고번호가 들어가요.', 1, 1),
('sdoc', '공급자적합성확인', '판매자가 직접(또는 시험을 맡겨) 기준에 맞는지 확인하는 방식이에요. 라벨에 KC마크만 들어가고 번호는 없어요.', 1, 0),
('compliance', '안전기준준수', '인증 절차는 없지만 안전기준과 표시기준은 지켜야 해요. KC마크를 붙이지 않아요.', 0, 0);

INSERT INTO source_priority (kind, priority) VALUES
('certificate', 1),
('manual', 2),
('photo', 3),
('product_name', 4);

INSERT INTO field_merge_rules (field_key, merge_mode, note) VALUES
('kc_mark', 'dedupe', 'KC마크 도안은 하나'),
('cert_no', 'list', '기준별 번호 모두'),
('product_name', 'dedupe', NULL),
('model_name', 'dedupe', NULL),
('maker', 'dedupe', NULL),
('importer', 'dedupe', NULL),
('maker_or_importer', 'dedupe', NULL),
('address_phone', 'dedupe', NULL),
('as_contact', 'dedupe', NULL),
('country', 'dedupe', NULL),
('mfg_date', 'dedupe', NULL),
('age', 'strictest', '어린이제품 쪽 우선'),
('rating', 'dedupe', '전기용품 쪽에서만'),
('caution', 'list', '중복 문장 제거'),
('std_marks', 'list', NULL),
('kc_notice', 'dedupe', NULL);

INSERT INTO label_templates (code, category, description) VALUES
('electric_base', 'electric', '전기용품 공통 뼈대: 정격·A/S 연락처 포함'),
('living_base', 'living', '생활용품 공통 뼈대: 주소 및 전화번호 포함'),
('kids_base', 'kids', '어린이제품 공통 뼈대');

INSERT INTO label_fields (template_code, item_id, sort_order, field_key, display_name, requirement, show_if, source, source_key, form_help, placeholder_text) VALUES
('electric_base', NULL, 10, 'kc_mark', 'KC마크', 'conditional', '{"var": "cert_type", "in": ["safety_cert", "safety_check", "sdoc"]}', 'fixed', 'KC', NULL, '(인증 후 표시)'),
('electric_base', NULL, 11, 'cert_no', '인증·신고번호', 'conditional', '{"var": "cert_type", "in": ["safety_cert", "safety_check"]}', 'form', NULL, '인증서의 번호', '(인증 후 발급번호 기재)'),
('electric_base', NULL, 20, 'product_name', '제품명', 'required', NULL, 'form', NULL, '판매할 때 쓰는 이름', NULL),
('electric_base', NULL, 30, 'model_name', '모델명', 'required', NULL, 'form', NULL, '제조자가 정한 모델명', '(모델명 확정 후 기재)'),
('electric_base', NULL, 40, 'rating', '정격', 'required', NULL, 'form', NULL, '예: AC 220 V 60 Hz 100 W', '(정격 확정 후 기재)'),
('electric_base', NULL, 50, 'mfg_date', '제조년월', 'required', NULL, 'form', NULL, '예: 2026년 10월', '(생산 시 기재)'),
('electric_base', NULL, 60, 'maker_or_importer', '제조자명(수입자명)', 'required', NULL, 'form', NULL, '국산은 제조자, 수입품은 수입자', NULL),
('electric_base', NULL, 70, 'as_contact', 'A/S 연락처', 'required', NULL, 'form', NULL, '지역번호 포함', NULL),
('electric_base', NULL, 80, 'country', '제조국명', 'conditional', '{"var": "is_import", "eq": true}', 'form', NULL, '수입품인 경우', NULL),
('electric_base', NULL, 90, 'std_marks', '전기용품 안전기준에서 규정한 표시사항', 'required', NULL, 'text_block', 'std_marks', NULL, NULL),
('living_base', NULL, 10, 'kc_mark', 'KC마크', 'conditional', '{"var": "cert_type", "in": ["safety_cert", "safety_check", "sdoc"]}', 'fixed', 'KC', NULL, '(인증 후 표시)'),
('living_base', NULL, 11, 'cert_no', '인증·신고번호', 'conditional', '{"var": "cert_type", "in": ["safety_cert", "safety_check"]}', 'form', NULL, '인증서의 번호', '(인증 후 발급번호 기재)'),
('living_base', NULL, 20, 'product_name', '제품명', 'required', NULL, 'form', NULL, '판매할 때 쓰는 이름', NULL),
('living_base', NULL, 30, 'model_name', '모델명', 'required', NULL, 'form', NULL, '제조자가 정한 모델명', '(모델명 확정 후 기재)'),
('living_base', NULL, 40, 'mfg_date', '제조연월', 'required', NULL, 'form', NULL, '로트번호로 대신할 수 있는 품목도 있음', '(생산 시 기재)'),
('living_base', NULL, 50, 'maker', '제조자명', 'required', NULL, 'form', NULL, '제품을 만든 회사', NULL),
('living_base', NULL, 60, 'importer', '수입자명', 'conditional', '{"var": "is_import", "eq": true}', 'form', NULL, '수입품에 한함', NULL),
('living_base', NULL, 70, 'address_phone', '주소 및 전화번호', 'required', NULL, 'form', NULL, '지역번호 포함', NULL),
('living_base', NULL, 80, 'country', '제조국명', 'conditional', '{"var": "is_import", "eq": true}', 'form', NULL, '수입품에 한함', NULL),
('living_base', NULL, 90, 'caution', '사용상 주의사항', 'required', NULL, 'text_block', 'caution', NULL, NULL);

INSERT INTO traits (code, name, description) VALUES
('may_use_power', '전기를 쓸 수 있는 비전기 품목', '불빛·소리·모터·발열·배터리가 붙을 수 있는 품목'),
('may_be_wireless', '무선 기능이 붙을 수 있는 품목', '블루투스 등'),
('may_contact_food', '음식이 닿을 수 있는 비식품 품목', NULL),
('may_contain_magnet', '자석이 들어갈 수 있는 품목', NULL),
('age_related', '연령 구분이 있는 품목', '어린이제품과 배타 관계일 수 있음');

INSERT INTO question_nodes (code, scope, category, item_id, group_id, trait_code, sort_order, question_text, help_text, input_type, save_as, show_if) VALUES
('cert_status', 'global', NULL, NULL, NULL, NULL, 0, '이 제품은 KC 인증을 받았나요?', NULL, 'single_choice', 'cert_status', NULL),
('origin', 'global', NULL, NULL, NULL, NULL, 40, '한국에서 만들었나요, 해외에서 만들어 들여왔나요?', NULL, 'single_choice', 'origin', NULL),
('catch_all', 'global', NULL, NULL, NULL, NULL, 90, '마지막으로, 아래 중 해당하는 게 있나요?', '여러 개 골라도 돼요', 'multi_choice', 'catch_all', NULL),
('e_power_source', 'category', 'electric', NULL, NULL, NULL, 20, '이 제품은 어떤 전원으로 작동하나요?', NULL, 'single_choice', 'power_source', NULL),
('e_low_voltage', 'category', 'electric', NULL, NULL, NULL, 21, '제품이 쓰는 전압이 교류 30 V 이하 또는 직류 42 V 이하인가요?', '제품이나 어댑터에 적힌 입력 전압을 보면 돼요. 예: DC 5 V, DC 12 V는 여기에 해당', 'single_choice', 'is_low_voltage', NULL),
('e_rated_input', 'category', 'electric', NULL, NULL, NULL, 22, '제품의 소비전력(정격입력)은 몇 kW인가요?', 'W로 적혀 있으면 1000으로 나눠 주세요. 예: 1200 W → 1.2', 'number', 'rated_input_kw', NULL),
('e_rated_kva', 'category', 'electric', NULL, NULL, NULL, 23, '정격용량은 몇 kVA인가요?', NULL, 'number', 'rated_kva', NULL),
('e_rated_hz', 'category', 'electric', NULL, NULL, NULL, 24, '정격주파수는 몇 Hz인가요?', NULL, 'number', 'rated_hz', NULL),
('e_explosion_proof', 'category', 'electric', NULL, NULL, NULL, 25, '폭발 위험 장소용으로 만든 방폭형 제품인가요?', NULL, 'single_choice', 'is_explosion_proof', NULL),
('e_machine_part', 'category', 'electric', NULL, NULL, NULL, 25, '다른 기계나 기구 안에 부착되는 특수구조 부품인가요?', NULL, 'single_choice', 'is_machine_part', NULL),
('e_data_only', 'category', 'electric', NULL, NULL, NULL, 25, '전기를 공급하지 않고 통신이나 데이터 전송에만 쓰는 제품인가요?', NULL, 'single_choice', 'is_data_only', NULL),
('l_furniture_tall', 'category', 'living', NULL, NULL, NULL, 20, '높이가 762 mm(약 76 cm) 이상인 가정용 서랍장이나 파일링캐비닛인가요?', '넘어짐 사고 위험 때문에 따로 관리하는 가구예요', 'single_choice', 'furniture_tall_drawer', NULL),
('l_bb_class', 'category', 'living', NULL, NULL, NULL, 20, '상자나 인증 서류에 "몇 세 이상"이라고 되어 있나요? (인증 전이면 판매할 연령)', '비비탄총 등급은 판매 계획이 아니라 시험에서 확인되는 성능으로 최종 결정돼요', 'single_choice', 'bb_class', NULL),
('t_power', 'trait', NULL, NULL, NULL, 'may_use_power', 55, '이 제품에 전기로 움직이는 기능이 있나요?', '불빛, 소리, 모터, 발열 등', 'single_choice', 'power_type', NULL),
('t_charger', 'trait', NULL, NULL, NULL, 'may_use_power', 56, '충전기를 같이 넣어서 파나요?', NULL, 'single_choice', 'charger_included', '{"var": "power_type", "eq": "rechargeable"}'),
('t_wireless', 'trait', NULL, NULL, NULL, 'may_be_wireless', 57, '블루투스나 와이파이 같은 무선 기능이 있나요?', NULL, 'single_choice', 'has_wireless', NULL),
('t_food', 'trait', NULL, NULL, NULL, 'may_contact_food', 58, '음식이나 음료가 직접 닿는 부분이 있나요?', NULL, 'single_choice', 'food_contact', NULL),
('t_magnet', 'trait', NULL, NULL, NULL, 'may_contain_magnet', 59, '떨어지거나 빠질 수 있는 자석이 들어 있나요?', NULL, 'single_choice', 'has_magnet', NULL),
('t_age', 'trait', NULL, NULL, NULL, 'age_related', 15, '이 제품은 주로 몇 살이 쓰나요?', '만 13세 이하 어린이가 쓰면 어린이제품 기준을 따를 수 있어요', 'single_choice', 'age_group', NULL);

INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '받았어요', 'done', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'cert_status';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '진행 중이에요', 'in_progress', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'cert_status';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '아직이에요', 'not_yet', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'cert_status';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '인증이 필요한지 모르겠어요', 'unknown', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'cert_status';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '한국에서 만들었어요', 'domestic', '{"is_import": false}', 'next', NULL, NULL FROM question_nodes WHERE code = 'origin';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해외에서 들여왔어요', 'import', '{"is_import": true}', 'next', NULL, NULL FROM question_nodes WHERE code = 'origin';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '전기나 배터리를 써요', 'power', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '무선 기능이 있어요', 'wireless', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '음식이 닿아요', 'food', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '입에 넣거나 빨 수 있어요', 'mouth', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '자석이 들어 있어요', 'magnet', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'catch_all';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '콘센트에 꽂아서 (교류)', 'ac', '{"power_type": "ac_plug"}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_power_source';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '충전식 배터리나 건전지로 (직류)', 'dc', '{"power_type": "rechargeable"}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_power_source';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '둘 다 돼요', 'both', '{}', 'escalate', NULL, '교류·직류 겸용은 적용 기준 확인이 필요해요.' FROM question_nodes WHERE code = 'e_power_source';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '모르겠어요', 'unknown', '{}', 'wait', NULL, '어댑터나 제품 뒷면의 전원 표시(AC/DC)를 확인해 주세요.' FROM question_nodes WHERE code = 'e_power_source';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네, 저전압이에요', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_low_voltage';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요 (예: AC 220 V)', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_low_voltage';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '모르겠어요', 'unknown', '{}', 'wait', NULL, '제품 표시나 어댑터 라벨의 전압을 확인해 주세요.' FROM question_nodes WHERE code = 'e_low_voltage';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_explosion_proof';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '네', 'yes', '{}', 'out_of_scope', NULL, '방폭형은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'e_explosion_proof';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_machine_part';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '네', 'yes', '{}', 'out_of_scope', NULL, '기계·기구 부착용 특수구조는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'e_machine_part';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'e_data_only';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '네', 'yes', '{}', 'out_of_scope', NULL, '통신·데이터 전용은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'e_data_only';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'l_furniture_tall';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'l_furniture_tall';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '어린이용 (만 13세 이하)', 'kids', '{}', 'escalate', NULL, '어린이용 비비탄총은 어린이제품 안전인증 품목이에요(가이드 자료 미수집, 전문가 확인).' FROM question_nodes WHERE code = 'l_bb_class';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '청소년용', 'teen', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'l_bb_class';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '성인용', 'adult', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'l_bb_class';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '모르겠어요', 'unknown', '{}', 'escalate', NULL, '등급을 알 수 없으면 전문가 확인이 필요해요.' FROM question_nodes WHERE code = 'l_bb_class';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '콘센트에 꽂아서 써요', 'ac_plug', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '충전해서 써요 (내장 배터리)', 'rechargeable', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '건전지를 넣어서 써요', 'dry_cell', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '전기를 안 써요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_charger';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_charger';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_wireless';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_wireless';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_food';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_food';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_magnet';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_magnet';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '3살 미만 아기', 'under_36m', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '3살~만 13세', '36m_to_13y', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '청소년·어른', 'over_13y', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '나이 상관없이 다 써요', 'all', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 't_age';

INSERT INTO trait_outcomes (trait_code, answer_value, outcome, target, relation, basis, verified) VALUES
('may_use_power', 'ac_plug', 'cross_check', 'electric', 'parallel', '교류 전원 → 전기용품 조건 질문으로 교차 확인', 0),
('may_use_power', 'rechargeable', 'add_item', 'battery', 'component', '내장 충전지 → 전지 기준 확인', 0),
('may_use_power', 'dry_cell', 'none', NULL, NULL, '교체용 건전지만 쓰는 경우 추가 품목 여부 확인 필요', 0),
('may_be_wireless', 'yes', 'escalate', NULL, NULL, '전파법 적합성평가 대상 여부 (팀 범위 밖)', 0),
('may_contain_magnet', 'yes', 'escalate', NULL, NULL, '어린이제품 자석 경고 여부 확인', 0),
('may_contact_food', 'yes', 'cross_check', 'food', 'parallel', '식품용 기구·용기 기준 교차 확인', 0),
('age_related', 'under_36m', 'cross_check', 'kids', NULL, '어린이제품 기준과 배타 관계 확인', 0),
('age_related', '36m_to_13y', 'cross_check', 'kids', NULL, '어린이제품 기준과 배타 관계 확인', 0);

INSERT INTO standard_refs (code, title, source_page, excerpt) VALUES
('KC 60227-1', '정격전압 450/750V 이하의 염화비닐 절연케이블, 제1부 : 일반요구사항', 461, '안전기준) KC 60227-1 : 정격전압 450/750V 이하의 염화비닐 절연케이블, 제1부 : 일반요구사항
▪
- 케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
- 도체의 최고온도가 70 ℃ 이상인 케이블은 그 기호 또는 도체의 최고 온도를 표시하여야 한다.
- 표시는 절연체 또는 외피 표면에 인쇄 혹은 요철(凹凸) 각인 중 선택하여 표시할 수 있다.
▪
각각의 명시된 표기는 연속적이어야 하며, 표기의 끝과 다음 표기 시작점과의 간격이 아래에 열거하는 거리를 초과하지
않아야 한다.
- 표기를 케이블 외피 표면에 하는 경우 550 mm
- 275 mm 마다 할 경우
표기를 외피가 없는 절연체 위에 할 때,
표기를 외피가 있는 케이블의 절연체 위에 할 때,
표기를 외피가 있는 케이블 내의 테이프 위에 할 때.
공
통
안
전
기
준
안전기준) KC 60245-1 : 정격전압 450/750V 이하의 고무절연케이블, 제1부 : 일반요구사항
▪
케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
표시는 절연체 또는 외피 표면에 인쇄 '),
('KC 60245-1', '정격전압 450/750V 이하의 고무절연케이블, 제1부 : 일반요구사항', 461, '안전기준) KC 60227-1 : 정격전압 450/750V 이하의 염화비닐 절연케이블, 제1부 : 일반요구사항
▪
- 케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
- 도체의 최고온도가 70 ℃ 이상인 케이블은 그 기호 또는 도체의 최고 온도를 표시하여야 한다.
- 표시는 절연체 또는 외피 표면에 인쇄 혹은 요철(凹凸) 각인 중 선택하여 표시할 수 있다.
▪
각각의 명시된 표기는 연속적이어야 하며, 표기의 끝과 다음 표기 시작점과의 간격이 아래에 열거하는 거리를 초과하지
않아야 한다.
- 표기를 케이블 외피 표면에 하는 경우 550 mm
- 275 mm 마다 할 경우
표기를 외피가 없는 절연체 위에 할 때,
표기를 외피가 있는 케이블의 절연체 위에 할 때,
표기를 외피가 있는 케이블 내의 테이프 위에 할 때.
공
통
안
전
기
준
안전기준) KC 60245-1 : 정격전압 450/750V 이하의 고무절연케이블, 제1부 : 일반요구사항
▪
케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
표시는 절연체 또는 외피 표면에 인쇄 '),
('KC 60799', '전기용 부속품 – 코드셋 및 상호연결 코드셋', 461, '안전기준) KC 60227-1 : 정격전압 450/750V 이하의 염화비닐 절연케이블, 제1부 : 일반요구사항
▪
- 케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
- 도체의 최고온도가 70 ℃ 이상인 케이블은 그 기호 또는 도체의 최고 온도를 표시하여야 한다.
- 표시는 절연체 또는 외피 표면에 인쇄 혹은 요철(凹凸) 각인 중 선택하여 표시할 수 있다.
▪
각각의 명시된 표기는 연속적이어야 하며, 표기의 끝과 다음 표기 시작점과의 간격이 아래에 열거하는 거리를 초과하지
않아야 한다.
- 표기를 케이블 외피 표면에 하는 경우 550 mm
- 275 mm 마다 할 경우
표기를 외피가 없는 절연체 위에 할 때,
표기를 외피가 있는 케이블의 절연체 위에 할 때,
표기를 외피가 있는 케이블 내의 테이프 위에 할 때.
공
통
안
전
기
준
안전기준) KC 60245-1 : 정격전압 450/750V 이하의 고무절연케이블, 제1부 : 일반요구사항
▪
케이블에는 제조자 표시를 하여야 한다. 이는 연속적인 식별표기나, 제조자 명 또는 상표의 반복 표기로 할 수 있다.
표시는 절연체 또는 외피 표면에 인쇄 '),
('KC 61058-1', '기기용 스위치 제1부 : 일반요구사항', 462, '안전기준) KC 61058-1 : 기기용 스위치 제1부 : 일반요구사항
▪
－ 기기 제조자가 스위치를 선택 및 설치할 수 있다.
－ 최종 사용자가 스위치 제조자가 의도한 것처럼 스위치를 사용할 수 있다.
－ 이 규격에 일치하는 시험을 할 수 있다.
이 정보는 표3에 상세히 나타내는 것처럼 다음의 하나 또는 둘 이상의 방법으로 준비한다.
▪
▪
이 문서의 내용은 언제나 적절한 임의의 서식으로 기기 제조자 또는 최종 사용자가 입수할 수있어야 한다.
비 고 1) Ma/Do가 지시하고 있을 경우, 정보는 표지나 문서에 의해 주어진다. 비고 2) 이 정보를 제공하는 문서 양식은
이 규격의 적용 범위에는 포함하지 않는다.
▪
－ 정격 전류(A) 또는 정격 형광등 부하 전류(AX)나 2개의 다른 정격을 조합하였을 경우에는 양쪽조합의 정격
정격 전압(볼트)
전원의 성질 기호
－ 제조자 명, 판매자 명, 상표 또는 식별 기호
－ 형번(카탈로그 번호일 경우도 있다.)
－ 미니 갭 구조의 기호(적용할 수 있는 경우에 한한다.)
－ 마이크로 갭 구조의 기호(적용할 수 있는 경우에 한한다.)
－ 반도체 개폐 장치의 기호(적용할 수 있는 경우에 한한다.)
－ 유해 부품에 대한 노출 '),
('K 60947-1', '가정용 및 이와 유사한 설비에 사용되는 과전류 보호용 차단기 : 교류용 차단기', 464, '비고 2) 푸시 버튼 스위치에 대해서는 표시할 필요가 없다.
▪
▪
비 고 1) 예를 들면 비밀폐형 스위치와 장착용 스위치에 대해서는 특별한 준비가 필요할 수도 있다.
비 고 2) 장착후 이 표준의 요구 사항을 충족시키는 데 필요한 조건이 달성되어 있음을 보증하기 하해 취급 설명서에는
아래 사항에 대해 명확한 정보가 포함되어야 한다.
－ 스위치에 필요한 공간의 치수
－ 스위치를 그 공간 내에서 유지하고 고정하는 도구의 치수와 위치
－ 장착된 장소에서 스위치의 각 부분과 주위와의 최소 거리
－ 필요할 경우 환기용 개구부의 최소 치수 및 그것들의 올바른 배치
－ 교체 가능한 파일럿 램프가 달린 스위치인 경우에는 사용될 램프에 대한 상세한 내용
안전기준) K 60947-1 : 가정용 및 이와 유사한 설비에 사용되는 과전류 보호용 차단기 : 교류용 차단기
▪
▪
관련제품규격에서 요구하는 경우, 제조자는 다음 정보를 제공해야 한다.
명시사항:
- 제조자의 명칭 또는 상표
- 형식명 또는 제조번호
- 제조자가 적합성을 주장하는 경우, 관련제품규격 번호
특성:
- 정격사용전압(4.3.1.1 및 5.2의 비고 참조)
- 기기의 정격사용전압에 대한 사용범주 및 정격사용전류('),
('KC 60947-2', '저압개폐장치 및 제어장치 제2부 : 차단기', 466, '필요하다면, 기기의 운송, 설치 및 동작에 관한 지시서에는 적절하고 올바른 설치, 취급 및 동작에 관해 특별히 중요한 방법이
기술되어야 한다.
이러한 문서에는 필요하다면, 유지보수의 범위 및 주기가 기재되어야 한다.
비 고) 이 기준의 대상이 되는 모든 기기가 반드시 유지보수 되도록 설계될 필요는 없다.
안전기준) KC 60947-2 : 저압개폐장치 및 제어장치 제2부 : 차단기
차단기에는 영구적인 방법으로 다음의 사항을 표시해야 한다.
a) 다음 데이터들은 차단기 본체 또는 차단기에 부착된 명판에 표기되어야 하고, 차단기가 설치된 상태에서 잘 보이고 읽을
수 있도록 위치해야 한다.
∙ 정격 전류(In)
∙ 적용할 수 있는 경우, 기호
와 함께 이격 기능에 대한 적합성
∙ 개로 및 폐로 위치의 표시, 기호를 사용하는 경우에는 ○와 ｜로 표시
b) 아래의 데이터들도 a)에 규정된 바와 같이 차단기 외부에 표시되어야 한다. 단, 이것들은 차단기가 설치되었을 때 보일
필요는 없다.
∙ 제조자명 또는 상호
∙ 형식명 또는 제조번호
∙ 제조자가 적합성을 주장하는 경우, KS C IEC 60947-2
∙ 사용범주
∙ 정격사용전압
∙ 정격임펄스내전압(Uimp)
∙ 정격'),
('K 61095', '가정용과 유사 용도를 위한 전기 기계적 접촉자', 467, '안전기준) K 61095 : 가정용과 유사 용도를 위한 전기 기계적 접촉자
다음 정보는 제조업자에 의해서 주어져야 한다:
a) 제조업자의 이름이나 상표;
b) 유형 지정이나 일련 번호;
c) 제조업자가 확인을 요구한다면. 이 표준의 수치.
▪
d) 정격 작동 전압
e) 정격 작동 전압에서 사용 범위와 정격 작동 전류(또는 정격 전력)
f) 정격 주파수/주파수들의 값. 예: 50Hz 또는 50Hz/60Hz;
g) 필요하다면. 주기적인 효율의 분류의 지시사항을 갖는 정격 효율
관련된 값들:
h) 정격 형성 용량과 차단 용량. 이 지시사항들은 사용 범위의 지시사항에 의해서. 적용가능한 곳에서 대체된다.
안전성과 설치:
i) 정격 절연 전압
j) 공표되었을 때. 정격 임펄스 내성 전압
k) 밀폐 접촉자의 경우. IP 코드
l) 오염 등급
m) 정격 조건 단락회로 전류와 유형. 전류 등급과 관련된 SCPD의 특성
n) 개폐 과전압
조절 회로
조절 회로와 관련된 다음 정보는 코일이나 접촉자 위에 놓여진다:
o) 정격 조절 회로 전압(Uc). 전류의 종류와 정격 주파수;
p) 전류의 종류가 필요하다면. 정격 주파수와 정격 조절 공급 전압(Us);
접촉자의 경우. SELV'),
('KC 60947-4-1', '저전압 개폐장치 및 제어장치 제4-1부: 접촉기 및 모터 기동기-전자식 접촉기 및', 468, '만약에 있다면 c) 상황에서 자료와 승인 표시(보증)은 명판 위에 놓여진다.
d)에서 j)와 l)에서 r)까지의 상황에서 자료는 명판이나 접촉자나 제조업자의 출판물에 포함되어져야 한다.
단자의 표시는 이 표준의 부속서 A와 일치하여야 한다.
주 - IEC 947-4-1에 따른 추가 사용 범위도 표시된다.
▪
만약에 있다면. 제조업자는 문서나 범위에서 작동하는 동안과 누전 후에 접촉자의 설치. 작동과 유지를 위한 조건을 구체화해야
한다.
필요하다면. 접촉자의 이송. 설치와 작동을 위한 지시사항은 적절하고 정확한 설치. 주문과접촉자의 작동의 경우 특별히
중요한 방법을 지정하여야 한다.
만약에 있다면. 이 문서들은 추천된 내용과 유지하는 주파수를 지정하여야 한다.
안전기준) KC 60947-4-1 : 저전압 개폐장치 및 제어장치 제4-1부: 접촉기 및 모터 기동기-전자식 접촉기 및
모터 기동기
a) 제조자의 이름 또는 등록 상표
b) 형식 명칭 또는 일련 번호
c) 제조자가 승낙을 요구한다면 이 규격의 번호
▪
특 성
d) 정격 작동 전압
e) 설비의 정격 작동 전압에서 이용 범주 및 정격 작동 전류(또는 정격 전력)
f) 정격 주파수/주파수의 값, 예를 들면 5'),
('KC 60384-14', '전자기기용 고정 커패시터 제1부 : 품목규격', 470, '안전기준) KC 60384-14 : 전자기기용 고정 커패시터 제1부 : 품목규격
표시되는 정보는 통상적으로 다음 항목에서 선택된다. 각 항목의 상대적 중요성은 위치 순서로 나타난다.
a) 제조자의 이름 또는 상표명
b) 제조자에 의한 형명 또는 개별규격에 의한 형명
c) 커패시터 등급 및 하위등급
d) 인정된 인증 표시
e) 정격 커패시턴스와 정격 저항
f) 정격 전압과 전원 성질(교류 전압은 ∼표시로, 직류 전압은 또는 표시로 나타낼 수 있다.
g) 결선 방법(필요시)
h) 도체의 정격 전류(리드관통형 커패시터의 경우)
i) 정격 커패시턴스의 허용오차, ±20 %가 아닌 경우
j) 기후 범주와 수동 가연성 범주를 나타내는 글자
k) 정격 온도
l) 제조 연월(또는 주)
m) 개별규격의 참고사항
1.6.1 커패시터에는 a), b), c)를 명확하게 표시하며, b)에 포함되지 않은 경우, d), e), f)를 표시한다. 나머지 항목에 대해서도
제조자가 필요하다고 여겨지는 만큼 많은 항목을 표시한다.
표시는 제조된 부품을 확실히 구분할 수 있게 해 주어야 한다.
비 고 표면실장부품은 a), b)만 의무적이다
안전기준) KC 60939-2 : 전자파장해 방지용 필'),
('KC 60939-2', '전자파장해 방지용 필터소자 제2부:품종규격-시험방법의 선택과 일반사항', 470, '안전기준) KC 60384-14 : 전자기기용 고정 커패시터 제1부 : 품목규격
표시되는 정보는 통상적으로 다음 항목에서 선택된다. 각 항목의 상대적 중요성은 위치 순서로 나타난다.
a) 제조자의 이름 또는 상표명
b) 제조자에 의한 형명 또는 개별규격에 의한 형명
c) 커패시터 등급 및 하위등급
d) 인정된 인증 표시
e) 정격 커패시턴스와 정격 저항
f) 정격 전압과 전원 성질(교류 전압은 ∼표시로, 직류 전압은 또는 표시로 나타낼 수 있다.
g) 결선 방법(필요시)
h) 도체의 정격 전류(리드관통형 커패시터의 경우)
i) 정격 커패시턴스의 허용오차, ±20 %가 아닌 경우
j) 기후 범주와 수동 가연성 범주를 나타내는 글자
k) 정격 온도
l) 제조 연월(또는 주)
m) 개별규격의 참고사항
1.6.1 커패시터에는 a), b), c)를 명확하게 표시하며, b)에 포함되지 않은 경우, d), e), f)를 표시한다. 나머지 항목에 대해서도
제조자가 필요하다고 여겨지는 만큼 많은 항목을 표시한다.
표시는 제조된 부품을 확실히 구분할 수 있게 해 주어야 한다.
비 고 표면실장부품은 a), b)만 의무적이다
안전기준) KC 60939-2 : 전자파장해 방지용 필'),
('KC 61048', '램프 보조장치 형광램프 및 방전램프용 커패시터-일반 및 안전', 471, '안전기준) KC 61048 : 램프 보조장치 형광램프 및 방전램프용 커패시터-일반 및 안전
▪
a) 제조자나 판매 책임자의 이름이나 상표
b) 제조자의 상품 번호나 모델 참조 번호
c) 정격용량과 허용오차
d) 정격전압
e) 방전 저항기가 있을 때, 그 기호
f) 전류 퓨즈가 있을 때, 그 기호
g) 정격주파수나 주파수 범위
h) 정격 최고 온도와 최저 온도 (예를 들면 －10 ℃/70 ℃)
i) 자기복원 커패시터의 기호
j) 직렬로 동작하기 위한 비－자기복원 커패시터의 경우
비－복원 기호가 있는 커패시터에 위 기호가 있어서는 안 된다.
비 고) 이 형식의 커패시터는 주 전원 사이에 연결되도록 의도된 것은 아니다.
k) 적용에 따른 A형 또는 B형
▪
a) 방전 저항기가 있을 때, 그 값의 선언
b) 커패시터가 (tc＋10) ℃에서 액체 상태인 성분의 포함 여부 선언
공
통
안
전
기
준
469'),
('KC 60320-1', '가정용 및 유사용도의 기기용 커플러 제1부 : 일반요구사항', 472, '안전기준) KC 60320-1 : 가정용 및 유사용도의 기기용 커플러 제1부 : 일반요구사항
커넥터는 다음과 같은 표시를 하여야 한다. －정격 전류(A). 다만 0.2 A 커넥터 제외
－ 정격 전압(V) －공급 전원 종류의 기호
－ 제조자명, 제조자의 상표 또는 식별 표시 또는 책임 판매자의 명칭
－ 형식명
－ 나사 없는 단자에 적합한 도체 형식을 나타내는 IEC 60999-1의 7.5항에 지정한 표시
비 고) 형식명은 카탈로그 번호이어도 된다.
▪ 기기용 인입구이면서 기기 또는 장치와 일체로 된 것 또는 기기나 장치의 내부에 조립된 것 이외의 것은 형식명, 제조자명,
제조자의 상표 또는 식별 또는 책임 있는 판매자의 명칭 및 식별 기호를 표시하여야 한다. 그리고 형식명은 기기용 인입구가
올바르게 부착되었을 때이거나 또는 커넥터가 꽂혔을 때 그 표시가 외부에서 보이면 안된다. 0.2 A용 및 2.5 A용 기기용
인입구의 표시는 그것이 기기 자체의 표시와 틀릴 우려가 없을 경우에는 외부에서 보여도 된다.
비 고) 형식명은 카탈로그 번호이어도 된다.
▪
▪
전류
전압
교류
A
V
~
접지
또는
비 고) 가능하면 동그라미 기호를 사용한다. 정격 전류 및 정격 전압'),
('KC 60884-1', '가정용 및 이와 유사한 용도의 플러그와 콘센트 제1부 : 일반요구사항', 473, '코드 교환형의 반대로 끼울 수 없는 커넥터의 단자는 다음과 같이 표시한다.
접지용 단자 : 기호
또는
중성선 전용 단자 : 문자 N
코드 비교환형의 반대로 끼울 수 없는 커넥터는 접점 표시를 할 필요는 없으나 코드의 선심은 22.1에서 규정한 대로 접속하여야
한다. 기기 또는 장치의 내부에서 일체로 된 또는 조립된 것 이외의 기기용 인입구는 이 항에 따르는 커넥터와 사용함에
있어 이 항에 대응하는 단자 표시가 있어야 한다. 표시 사항에서 요구하고 있는 기호 또는 문자는 나사, 분리 가능한 와셔
또는 기타 해체할 수 있는것에 있지 말아야 한다.
비 고) 도체의 단자 및 접속 표시와 관련한 요구사항은 각국이 기존에 규정한 전원극 체계를 참작하여 도입하며 통합 플러그와
소켓-콘센트 체계의 추가 도입은 극성 체계를 크게 확장하게 될 것이다. 이 요구사항은 현재 무극 플러그 및 소켓-콘센트
체계를 갖는 국가에 참작하도록 권고하는 것이다. 교환형 커넥터는 다음의 지침대로 공급하여야 한다.
a) 도체 접속 방법 특히 접지 도체의 길이(초과분) 및 코드 고정 용구의 작동 방법을 표시하는 도면
b) 탈피면 슬리브 및 절연 길이를 표시하는 실제 크기 도면
c) 적합한 코드의 '),
('K 10026', '대기전력 자동 차단 콘센트', 475, '▪
적합성 여부는 검사를 통해 판정된다.
▪
적합성 여부는 검사나 다음의 시험을 통해 판정된다.
물에 적신 헝겊으로 15초간 손으로 문지른 후 석유 용제를 묻힌 헝겊으로 15초간 다시 문지른다.
비 고 1) 각인, 몰딩, 프레싱, 조각에 의한 표시는 이러한 시험을 거치지 않는다.
비 고 2) 사용되는 석유 용제는 최대 0.1 %, 약 29의 카우리부탄올 (kauributanol)값, 최초 비등점 약 65 ℃, 건조점 약
69 ℃, 농도 약 0.68 g/cm3 인 방향족 화합물 헥산 용액을 권장한다.
안전기준) K 10026 : 대기전력 자동 차단 콘센트
▪
- 정격전류 A
- 정격전압 V
- 작동시 소비전력 W
- 차단시 소비전력 W
- 과부하 차단전류 A
- 전원종류의 기호
- 대기전력 차단방법 (부하감지, 조도, 기타)
- 제조자 및 판매자 명, 상표 또는 마크
- 형번 (카탈로그 번호도 가능)
- 대기전력 차단 콘센트 표시 (표시는 문자 또는 녹색으로 표시함)
- 미니 갭 구조의 기호 (적용할 수 있는 경우에 한한다)
- 마이크로 갭 구조의 기호 (적용할 수 있는 경우에 한한다)
- 반도체 개폐 장치의 기호 (적용할 수 있는 경우에 한한다)
- 위험물로'),
('KC 61242', '전기용부속품-가정용 및 이와 유사한 용도의 케이블릴', 477, '비 고) 코드 교환형 이동형 대기전력 자동 차단 콘센트의 형번은 외함 또는 커버의 안쪽에 표시된다.
▪
보호도체의 연결을 위한 접지단자는
기호로 표시한다.
이러한 표시는 나사나 분리가 용이한 다른 부품에 표시되지 않는다.
비 고 1) “분리가 용이한 부품”이란 대기전력 자동 차단 콘센트의 일반 설치시에 분리 가능한 부품을 말한다.
비 고 2) 코드 비교환형의 영구 고정용 단자는 표시되지 않아도 된다.
대기전력 자동 차단 콘센트의 주요 기능 부품을 형성하지 않는 도체 연결용 단자는 용도가 분명하지 않으면 명확하게 식별되거
나 대기전력 자동 차단 콘센트에 고정되는 배선도에 표시되어야 한다.
이러한 단자는 다음과 같이 표시될 수 있다:
- K 60417-2에 의한 그래프 기호나 색깔 및 문자숫자 방식
- 물리적 치수나 상대적 위치
이 항목에서는 네온램프나 표시램프의 리드선을 도체로 보지 않는다.
▪
설치박스에서는 대기전력 자동 차단 콘센트가 일반용도와 동일하게 설치되고 배선될 때 식별이 용이하도록 하기 위하여
연결된 외함의 외부에 IP코드가 기재되어야 한다.
▪ IPX0보다 높은 IP 등급의 매입형 및 바닥 매입형의 보호등급이 어느 등급에 있는지 또는 어떤 규정('),
('KC 60127-1', '소형 퓨즈 : 소형 퓨즈의 정의 및 소형 퓨즈링크의 일반 요구사항', 479, '안전기준) KC 60127-1 : 소형 퓨즈 : 소형 퓨즈의 정의 및 소형 퓨즈링크의 일반 요구사항
표시사항
이후 다른 언급이 없으면 표시에 대한 요구사항은 다음과 같다.
▪
a) 1 A 미만의 정격전류는 ㎃단위로 표시하고, 1 A 이상의 정격전류는 A로 표시한다. 정격전류는 정격 전압보다 앞서
표기하되, 정격전압에 인접하게 표시한다.
현재 몇몇 나라에 존재하는 관행을 수용하기 위해, 전류는 분수로도 표시될 수 있다.
b) 정격전압은 V로 표시
c) 제조자의 이름이나 상표
d) 관련 표준시트에 주어진 대로 상대 용단 시간/전류 특성을 나타내는 기호 표시
이들 기호는 다음과 같다.
FF : 매우 빠른 동작 표시
F : 빠른 동작 표시
M : 중간 시간 지연 표시
T : 시간 지연 표시
TT : 긴 시간 지연 표시
공
통
안
전
기
준
▪
물에 적신 천조각으로 15 초간 손으로 문지르고, 석유 원액에 적신 천조각으로 15초간 문지르는 시험을 통해 적합성을 확인한다.
비 고 1) 석유 원액으로 최대 0.1 % 정도의 방향 성분을 가진, 카우리 부탄올 29, 비등점 약 65 ℃, 마른 점 약 69 ℃
그리고 비중 약 0.68 정도의 지방성 용매 핵산을 사용할 것을 '),
('KC 60691', '온도 퓨즈 - 요구사항 및 적용지침', 479, '안전기준) KC 60127-1 : 소형 퓨즈 : 소형 퓨즈의 정의 및 소형 퓨즈링크의 일반 요구사항
표시사항
이후 다른 언급이 없으면 표시에 대한 요구사항은 다음과 같다.
▪
a) 1 A 미만의 정격전류는 ㎃단위로 표시하고, 1 A 이상의 정격전류는 A로 표시한다. 정격전류는 정격 전압보다 앞서
표기하되, 정격전압에 인접하게 표시한다.
현재 몇몇 나라에 존재하는 관행을 수용하기 위해, 전류는 분수로도 표시될 수 있다.
b) 정격전압은 V로 표시
c) 제조자의 이름이나 상표
d) 관련 표준시트에 주어진 대로 상대 용단 시간/전류 특성을 나타내는 기호 표시
이들 기호는 다음과 같다.
FF : 매우 빠른 동작 표시
F : 빠른 동작 표시
M : 중간 시간 지연 표시
T : 시간 지연 표시
TT : 긴 시간 지연 표시
공
통
안
전
기
준
▪
물에 적신 천조각으로 15 초간 손으로 문지르고, 석유 원액에 적신 천조각으로 15초간 문지르는 시험을 통해 적합성을 확인한다.
비 고 1) 석유 원액으로 최대 0.1 % 정도의 방향 성분을 가진, 카우리 부탄올 29, 비등점 약 65 ℃, 마른 점 약 69 ℃
그리고 비중 약 0.68 정도의 지방성 용매 핵산을 사용할 것을 '),
('KC 60934', '기기보호용 차단기(CBE)', 480, '비 고 2) “가볍게 문지르기” 대신에 그림 G.1의 기구를 사용할 수 있다. 온도 퓨즈의 크기가 작다면, 그리고 교체되어지지
않도록, 상기 a), b), c) 및 d)에 따른 표시는 이 기준 번호와 함께 포장에 인쇄되어야 한다.
▪
제조자는 7항에서 요구한 내용에 추가적으로 다음의 내용을 삽입하여 기술문서, 카탈로그 또는 사용 설명서를 제공하여야
한다.
a) 6항에 따른 분류
b) 아래 분류 사항
1) 온도 특성 Tf, Th, Tm
2) 전류 특성 Ir, Ib, Ip
3) 정격전압 Ur c) 봉인의 적합성 또는 주입액이나 세정제의 사용여부
d) 온도 퓨즈 설치에 대한 정보
e) 크기가 작은 온도 퓨즈 그리고 교체되어지지 않음
비 고 1) 온도 퓨즈의 손상을 막기 위하여, 최종사용자의 제품사용이 봉인 또는 세정제의 사용과 관련이 있는지 제조자는
반드시 확인하여야 한다.
비 고 2) 안전을 위하여 기술문서에는 온도 퓨즈는 수리 불가 항목이며, 교체의 경우, 같은 제조자의 카탈로그 번호가 같은
제품으로 반드시 전과 동일한 방법으로 설치해야 한다는 것을 명시해야 한다.
비 고 3) 카탈로그나 관련번호로 온도 퓨즈를 분류하는 온도, 전류 및 전압 같은 파라미터를 규'),
('KC 60898-1', '가정용 및 이와 유사한 설비에 사용 되는 과전류 보호용 차단기', 481, '비 고 1) 정면에 표시사항을 표시하는 것은 CBE 필수 규정이 아니다. CBE는 CBE 제조자가 제공한 정보를 토대로 그 장비에
OEM으로 규정되기 때문이다. 대개 소형 CBE에서 공간이 부족하여 설치 후 눈에 보이는 정면부에 표기를 할 수 없는 경우가
있을 수 있다. CBE에서 눈에 보이는 곳에 표기하지 않은 경우 제조자는 OEM에게 자신의 장비를 이와 같이 표기하였음을
알리는 것이 바람직하다. 푸시 버튼 방법으로 동작되는 것 이외의 CBE에 있어서 개방 지점은 기호 “O”, 그리고 닫힘 지점은
기호 “I”(짧은 수직 직선 라인)로 표시해야 한다. 2개의 푸시 버튼 방법으로 동작되는 CBE는 단지 개방 동작을 위해 설계된
푸시 버튼을 붉은색 및/ 또는 기호 “O”로 표시되어야 한다.
비고 2) “O”와 “I” 이외의 기호도 국가 기호로 허용된다. 붉은색은, 예를 들면 핸들, 잠금 장치와 같이 ON과 OFF 위치가
명확하게 구분되어 제공된 기동기의 특정 형식을 위해 사용되는 것 외에 다른 어떤 푸시 버튼에도 사용되어서는 안 된다. 전원과
부하 단자 사이의 구분이 필요할 경우 전자는 CBE를 가리키는 화살표로 표시하고 후자는 CBE로부터 멀어지는 방향의 화살'),
('KC 60947-1', '가정용 및 이와 유사한 설비에 사용되는 과전류 보호용 차단기 : 교류용 차단기', 482, '누름버튼 이외의 방법으로 동작되는 차단기의 경우, 개로위치는 기호 “O”로, 폐로위치는 “｜”로 표시되어야 한다. 이러한
표시를 위해 추가로 사용되는 국내용 기호는 허용된다. 국내용 기호만 사용하는 것은 임시적으로 허용된다. 이러한 기호들은
차단기가 설치되었을 때 쉽게 볼 수 있어야 한다.
두 개의 누름버튼으로 동작되는 차단기의 경우, 개방동작만을 위한 누름버튼은 적색이어야 하고/하거나 기호“O”로 표시되어야
한다.
2 에 따른 분류를 표시하고, 이에 맞게 차단기에 표시하여야 한다.
누름버튼 이외의 방법으로 동작되는 차단기의 경우, 개로위치는 기호 “O”로, 폐로위치는 “｜”로 표시되어야 한다. 이러한
표시를 위해 추가로 사용되는 국내용 기호는 허용된다. 국내용 기호만 사용하는 것은 임시적으로 허용된다. 이러한 기호들은
차단기가 설치되었을 때 쉽게 볼 수 있어야 한다.
두 개의 누름버튼으로 동작되는 차단기의 경우, 개방동작만을 위한 누름버튼은 적색이어야 하고/하거나 기호“O”로 표시되어야
한다.
적색은 차단기의 다른 누름버튼에 대해 사용되지 않아야 한다. 누름버튼이 접점을 투입하는데 사용되고 그러한 것으로 명백히
구분되어지는 경우, 그것의 눌러진 위치는 폐로'),
('KC 61008-1', '가정용 및 이와 유사한 용도의 과전류 보호장치가 없는 누전차단기(RCCB) 제1부 :', 484, '이 요구사항은 또한 기호가 결선도에 표시되어 있고 이 결선도가 이격에 대한 적합성을 나타내는 유일한 표시인 경우에도
적용된다.
전자식 제어 전자석의 경우, 5.1에 제시되어 있는 이외의 정보가 요구될 수도 있다.
비범용 비나사용 단자에 대한 "s", "sol", "r" 또는 "f" 표시는 장치에 표시하거나, 공간이 충분치 않을 경우 최소 포장 단위
또는 제품과 함께 제공되는 기술 정보에 표시해야 한다.
같은 곳에 위치한 단자들의 경우, 장치 상의 단일 표시가 허용된다.
설치, 동작 및 유지보수에 대한 지시
제조자는 설치와 관련하여 동작중 및 고장후의 기기의 동작 및 유지보수 조건을 필요에 따라 문서 또는 카탈로그에 명기해야한다.
제조자는 또한 필요하다면, EMC와 관련된 대책을 규정해야한다. 환경 A(7.3.1 참조)에만 적합한 기기에 대해서 제조자는
다음 주의사항을 문서에 기술해야 한다.
주 의
이 제품은 환경 A에 부합하도록 설계되었다. 환경 B에서의 이 제품의 사용은 불필요한 전자기 방해를
유발할 수 있으며, 이 경우 사용자는 적절한 완화 대책을 강구할 필요가 있다.
필요하다면, 기기의 운송, 설치 및 동작에 관한 지시서에는 적절하고 올바른 설치, 취급'),
('KC 61009-1', '가정용 및 이와 유사한 용도의 과전류 보호장치를 가진 누전차단기(RCBO) 제1부 :', 485, '표시사항은 RCCB 본체 또는 RCCB에 부착된 명판에 표시되어야 하고, RCCB가 설치된 상태에서 읽기 쉬운 곳에 위치해야
한다. 이 표준의 모든 RCCB가 갖고 있는 이격에 대한 적합성은 기기상에 기호
를 사용해서 표시할 수도 있다. 이
표시는 결선도에 포함될 수도 있는데, 이 결선도에서 다른 기능의 기호들과 조합되어 있을 수도 있다.
기기상에 기호를 표시하는 경우(즉, 결선도에 표시하지 않고), 다른 기능의 기호들과 조합해서 표시하는 것은 허용되지 않는다.
KS C IEC 60529에 따른 IP20보다 더 높은 보호등급을 기기상에 표시한 경우, 설치방법이 무엇이든지 간에 그것을 만족해야
한다. 특정의 설치방법에 의해서만, 그리고/또는 특정 부속품(예를 들면, 단자 덮개, 외함 등)의 사용으로 더 높은 보호등급이
얻어진다면, 제조자의 안내 책자에 이것을 명시해야 한다. 모든 사항을 표시할 공간이 없는 작은 기기의 경우에는 최소한 e),
f) 및 o)의 사항을 표시해야 하고, 기기가 설치되었을 때 잘 보이도록 해야 한다. a), b), c), k), l) 및 p)의 사항은 기기의
옆이나 뒷면에 표시할 수도 있고, 기기가 설치되기 전에만 보이게 할 수도 있다'),
('KC 61558-1', '전력용 변압기, 전원공급장치 및 유사기기의 안전 제1부 : 일반요구사항 및 시험', 487, '안전기준) KC 61558-1 : 전력용 변압기, 전원공급장치 및 유사기기의 안전 제1부 : 일반요구사항 및 시험
표시 및 사용 설명서
▪
a) 볼트 단위 정격 공급 전압 또는 정격 공급 전압 범위
정격값 범위를 가지고 그 범위 전체를 통틀어 조정 없이 작동될 수 있는 변압기는 하이픈(－)에 의해 분리된 최저 범위와
최고 범위를 표시해야 한다.
비 고 1) 예로 115~230 V：변압기는 표시 범위 내 임의의 어떠한 값에서도 사용할 수 있다.
정격이 달라 사용자나 설치자가 특정값에서 사용시 수정해야 하는 변압기는 그 값을 사선으로 구분하여 표시한다.
비 고 2) 예로 115~230 V：이 변압기는 표시된 값에서만 사용해야 한다(셀렉터 스위치를 가진 변압기).
비 고 3) 이러한 요구 사항은 또한 단상이나 다상 공급원 두 가지 모두를 연결하기 위한 장치를 가진 변압기에도 적용된다.
예를 들면 230 V/400 V：이 변압기는 단상 작동을 위한 지정 전압이 230 V이고, 3상 작동을 위한지정 전압이 400 V일
경우에만 사용해야 한다(두 개 공급원을 위한 터미널을 갖춘 변압기).
b) 볼트 또는 킬로볼트 단위 정격 출력 전압
정류기 통합 변압기들에 있어서 정류'),
('KC 60335-1', '가정용 및 이와 유사한 전기기기의 안전성 제1부 : 일반요구사항', 490, '안전기준) KC 60335-1 : 가정용 및 이와 유사한 전기기기의 안전성 제1부 : 일반요구사항
▪
- 정격 전압 또는 정격 전압 범위 [V]
- 정격 주파수 표시가 되어 있지 않은 것은 전원 종류의 기호
- 정격 입력 [W] 또는 정격 전류 [A]
- 제조자명 또는 책임 있는 판매자명, 상표 또는 식별할 수 있는 표시
- 모델명 또는 형식 기준
- 2종 기기에 한하여 기호 IEC 60417-5172 (2003-02)
- 물의 침입에 대한 보호 등급에 따른 IP 번호(IPX0은 제외)
- 3종 기기에 한하여 기호 IEC 60417-5180 (2003-02). 이 표시는 축전지(기기 외부에서 충전되는 1차 전지 또는 2차
전지)만으로 작동하는 기기에는 필요하지 않다.
▪ 기기를 수도관에 연결하기 위해 외부 호스 세트에 내장된 전기동작식 급수 밸브의 외함에는 그 동작 전압이 초저전압을
초과한다면 기호 IEC 60417-5036 (2002-10)을 표기하여야 한다.
▪ 복수 전원용 거치형 기기에는 다음과 같은 경고문을 표시하여야 한다.
▪ 경고: 단자에 닿기 전에 모든 전원회로를 차단할 것
▪ 이 경고문은 단자 커버 근방에 표시되어야 한다.
▪ 정격값의 범위가 '),
('KC 60745-1', '수지형전동공구의 안전성 제1부 : 일반요구사항', 493, '안전기준) KC 60745-1 : 수지형전동공구의 안전성 제1부 : 일반요구사항
표시 및 사용설명서(Marking and instructions)
▪
- 정격 전압 또는 정격 전압범위(V). 스타－델타 결선의 공구는 두 정격 전압을 확실히 표시한다(가령 230 D/400Y).
- 정격 주파수가 표시되어 있지 않다면, 전원 종류의 기호
- 정격 입력(W, kW) 또는 정격 전류(A). 공구에 표시되는 정격 입력 또는 전류는 회로에 동시에 흐르는 총 최대 입력
또는 전류이다. 만일 공구가 제어장치에 의해 선택될 수 있는 대체 부품을 가지고 있다면, 정격 입력은 가능한 최대 부하에
해당하는 것이다.
- 제조자명 또는 책임 있는 판매자명, 상표 또는 식별할 수 있는 표시
- 모델명 또는 형식
- 2종 공구에 있어서는 이중절연기호
- IPX0을 제외한 물의 침입에 대한 보호등급에 따른 IP 번호. IP 번호의 첫 번째 숫자는 공구에 표시 할 필요는 없다.
- 제조자 주소 또는 제조국
- 이 규격과 관련된 관계법령을 따름을 보여주는 강제 마크
오해가 일어나지 않는 경우는 상기 이외의 추가적인 표시를 할 수 있다. 부품에 별개로 표시하는 경우에는 공구의 표시
및 부품의 '),
('K60065', '오디오, 비디오기기 및 이와 유사한 전자기기의 안전', 495, '안전기준) K60065 : 오디오, 비디오기기 및 이와 유사한 전자기기의 안전
▪
a) 제조자 또는 책임 있는 판매인의 이름, 상표 또는 증명 표시 ;
b) 모델명 또는 형명 ;
c) 2종 기기(이중절연기기)에 대한 표시
d) 전원의 종류 :
- 교류전용기기에 대한 기호
- 직류전원에 대한 기호
- 교류･직류 겸용 기기에 대한 기호
- 3상 계통은 K 61293에 따른다.
e) 전압조절장치의 조정없이 적용가능한 정격전압범위 또는 정격전압. 다른 정격전압이나 정격전압범위로 설정할 수 있는
기기는, 기기가 설정된 전압이나 전압범위의 표시가 사용시 식별할 수 있는 구조로 되어야 한다. 사선은 사용자가 정격을
선택할 수 있을 때 “110/230 V”와 같은 형태로 사용하고, 하이픈은 “110-230 V”처럼 정격범위에 대해 사용한다.
f) 안전이 주전원 주파수의 사용에 의존한다면, 정격 주전원 주파수(또는 주파수범위)를 헤르쯔 (hertz)로 표시한다.
g) 범용 전원공급장치로부터 공급받는 기기의 정격소비전력. 대안으로써 정보가 사용설명서에 주어질 수 있다. 정격전압에서
측정된 소비치는 표시치의 10 % 를 초과해서는 안된다.
h) 교류 주전원으로 연결되는 기기의 '),
('K 60950-1', '정보기술기기-안전 제1부 : 일반 요구사항', 496, '안전기준) K 60950-1 : 정보기술기기-안전 제1부 : 일반 요구사항
기기는 정격 전력 표시와 정확한 전압과 주파수 공급을 명시하는 기기의 용도, 적절한 전류용량을 제공 해야 한다.
▪ 교류 주전원이나 직류 주전원에 직접 접속하는 수단을 제공하지 않는 기기의 경우 정격전압, 정격전류, 정격주파수 등의
전기적 정격을 표시할 필요는 없다. 기기 또는 시스템에 복수의 주전원 접속부가 있으면 각 개별 주전원의 전기 정격을
표시해야 하지만 기기 또는 시스템의 총 전기 정격은 표시할 필요가 없다.
▪ 사용자가 설치하는 기기의 경우, 요구 시, 전력 정격 표시는 작업자 접근 구역에서 쉽게 보일 수 있어야 한다. 작업자가
수동 전압 선택기에 접근할 수 없다면 전력 정격 표시로 기기 제조 당시 설정한 정격 전압을 나타내야 하며, 이 목적을
위해 임시 표시가 허용된다. 중량이 18 kg을 초과하는 기기의 바닥을 제외하고 전력 정격 표시는 기기 외부 표면에 어느
곳에서나 부착할 수 있다.
거치형 기기의 경우, 전력 정격 표시는 기기가 설치된 후 정상적인 이용 시 잘 보여야 한다.
서비스 요원이 설치하는 기기의 경우, 전력 정격 표시가 서비스 접근구역에 있으면 영구적인 표시'),
('KC 60598-1', '등기구 제1부 : 일반요구사항 및 시험', 498, '안전기준) KC 60598-1 : 등기구 제1부 : 일반요구사항 및 시험
▪ 정격전력
▪ 특수램프
▪ 저온 빔
▪ 볼 미러 램프
▪ 보호 실드(깨진 보호 실드는 교체하시오 or 그림1참조)
▪ 이그나이터 경고 문구 또는 심볼
▪ 자기차폐램프
▪ 내장 교체형 퓨즈 기호
▪ 원산지 표시(등록상표, 제조자 마크, 판매자)
▪ 정격전압
▪ 2종 등기구 기호
▪ 3종 등기구 기호
▪ IP표시, 일반적인등기구의IP20 표시는 요구되지 않음
▪ 모델명 또는 형식
▪ 보통 가연성 표면에 부착이 부적합한 등기구에 대한 기호
▪ 전원단자 접지단자 기호
▪ 루프형 등기구의 최대 연결 갯수
▪ 내열물질로 덮기 부적합한 등기구의 기호
▪ 조사등 같은 경우 조명을 받는 물체와의 최소 거리에 대한 기호
▪ 친 환경에서 사용하는 등기구에 대한 기호
▪ 필요하다면 분명하지 않은 조정 수단의 식별 표시
▪ 조합 등기구에서 기본 등기구와 동등하지 않을 경우 표시
▪ 정격주파수
496'),
('K 62477-1', '전력전자 변환기기 및 시스템(PECS)-제1부 : 일반', 499, 'K 62477-1 : 전력전자 변환기기 및 시스템(PECS)-제1부 : 일반
▪ 안전확인신고 마크
▪ 안전확인신고 번호
▪ 모델명
▪ 제조업체명 또는 수입업체명
▪ 제조시기를 알 수 있는 표시
▪ A/S 연락처
공
통
안
전
기
준
▪ 정격전압, 주파수, 전류, 위상
▪ 전력 정격
▪ IP등급
▪ 접촉전류
▪ 커패시터 방전시간
KC 62619 : 산업용 리튬이차전지 안전
별도 안전기준에서 요구하는 의무 표시사항 없음
497'),
('KC 62619', '산업용 리튬이차전지 안전', 499, 'K 62477-1 : 전력전자 변환기기 및 시스템(PECS)-제1부 : 일반
▪ 안전확인신고 마크
▪ 안전확인신고 번호
▪ 모델명
▪ 제조업체명 또는 수입업체명
▪ 제조시기를 알 수 있는 표시
▪ A/S 연락처
공
통
안
전
기
준
▪ 정격전압, 주파수, 전류, 위상
▪ 전력 정격
▪ IP등급
▪ 접촉전류
▪ 커패시터 방전시간
KC 62619 : 산업용 리튬이차전지 안전
별도 안전기준에서 요구하는 의무 표시사항 없음
497');
