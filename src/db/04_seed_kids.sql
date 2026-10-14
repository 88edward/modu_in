-- =====================================================================
-- 04_seed_kids.sql : 어린이제품 28개 (부록 C 기반, 수작업 정리 → 검수 전)
-- 근거: safetyguide.kr 표시사항가이드 (어린이제품) 품목 페이지 28개 (2026-10-01 열람본 PDF)
--
-- 넣은 것
--   items(K-01~K-28, id 7001~7028) · item_aliases · item_templates(kids_base)
--   label_fields: kids_base 공통 뼈대 + 품목별 "추가" 항목 ([..] 조건은 condition_text, 판정 가능하면 show_if)
--   question_nodes(scope=item) · question_options : "적용 제외 확인"은 보기별 action
--       대상 아님 → out_of_scope / K-xx로 전환 → switch_item / 전문가 확인 → escalate
--   item_groups(kind=age_class, selector=t_age) : 생활용품 짝과 연령 등급 분기
--   item_relations(parallel/component) · item_scope_rules · item_traits
--   text_blocks: caution / warning / care / manual / display_method / source_note(원문 오류 메모)
--
-- 주의
--   * 부록 C는 요약본이라 여러 줄 문구는 첫 줄만 있음 → "(원문 N줄 중 첫 줄만 수록)" 줄을 붙이고 needs_review=1
--   * 그림으로만 실린 경고문구는 문구 대신 근거 조항을 적음 → needs_review=1, needs_standard_text=1
--   * 보기 목록이 "… 외 N개"로 잘린 곳: 완구 특징(안전표시 조건 코드로 복원), 학용품 종류(적용범위 문장으로 복원),
--     섬유제품 종류의 마지막 보기("기타", K-21은 "신생아용품"도)는 추정 — 원문 확인 필요
--   * K-04 가죽제품 세부 분기(분기설계 7.2)는 문서가 없어 아직 넣지 않음
-- =====================================================================
PRAGMA foreign_keys = ON;

INSERT OR IGNORE INTO variables (name, description, value_type) VALUES
('kids_exclusion', '어린이제품 적용 제외 확인 결과', 'enum'),
('textile_type', '섬유제품 종류', 'enum'),
('small_parts', '떨어질 수 있는 작은 부품', 'enum'),
('soft_resin_shoes', '연질·발포 합성수지 신발', 'enum'),
('bed_structure', '이단침대 구조', 'enum'),
('furniture_type', '가구 종류', 'enum'),
('furniture_age', '가구 사용 연령', 'enum'),
('skate_use', '롤러스케이트 용도', 'enum'),
('water_toy_type', '물놀이기구 종류', 'enum'),
('ski_type', '스키용구 종류', 'enum'),
('protector_type', '스포츠 보호용품 종류', 'enum'),
('helmet_visor', '안전모 눈 보호구', 'enum'),
('eyewear_type', '안경테/선글라스', 'enum'),
('visible_transmittance', '가시광선 투과율(%)', 'number'),
('uv_separate', 'UV-A·B 차단율 각각 표시 가능', 'enum'),
('stick_type', '붙이는 온열팩', 'enum'),
('bike_saddle_mm', '안장 최대 높이(mm)', 'number'),
('training_wheels', '보조바퀴', 'enum'),
('jewelry_material', '장신구 주재질', 'enum'),
('kick_handbrake', '킥보드 핸드브레이크', 'enum'),
('kick_powered', '전동 킥보드', 'enum'),
('toy_age', '완구 사용 연령', 'enum'),
('toy_features', '완구 특징(복수 선택)', 'text'),
('toy_pack_with', '완구 동봉 품목', 'enum'),
('stroller_type', '유모차 형식', 'enum'),
('stroller_accessories', '유모차 동봉 부속품(복수 선택)', 'text'),
('parent_handle', '보호자 손잡이 봉', 'enum'),
('filling', '충전재', 'enum'),
('sleeping_bag_carpet', '침낭·카페트', 'enum'),
('metal_accessory', '금속 액세서리', 'enum'),
('infant_chair_type', '유아용 의자 종류', 'enum'),
('crib_type', '유아용 침대 종류', 'enum'),
('crib_powered', '전동 흔들림', 'enum'),
('carrier_frame', '캐리어 프레임', 'enum'),
('carrier_type', '캐리어 방식', 'enum'),
('carrier_stand', '캐리어 스탠드', 'enum'),
('crs_type', '어린이보호장치 종류', 'enum'),
('crs_group', '체중 그룹(복수 선택)', 'text'),
('crs_category', '사용범주', 'enum'),
('crs_fix', '고정 방법', 'enum'),
('crs_direction', '장착 방향', 'enum'),
('crs_aux_belt', '보조벨트', 'enum'),
('school_type', '학용품 종류', 'enum'),
('sharpener_power', '연필깎이 작동 방식', 'enum'),
('scented', '향기 나는 제품', 'enum'),
('resin_type', '합성수지제 어린이용품 종류', 'enum'),
('mat_type', '바닥매트 종류', 'enum'),
('puzzle_play', '퍼즐매트 놀이 기능', 'enum'),
('kids_other_confirm', '개별 품목 비해당 확인', 'enum');

INSERT OR IGNORE INTO field_merge_rules (field_key, merge_mode, note) VALUES
('warning', 'list', '경고문구·안전표시: 중복 문장 제거'),
('care', 'list', '취급상 주의사항'),
('manual', 'list', '사용설명서 기재사항');

-- 어린이 공통 뼈대 (공통안전기준 5.7·5.8)
INSERT INTO label_fields (template_code, item_id, sort_order, field_key, display_name, requirement, show_if, source, source_key, form_help, placeholder_text, condition_text) VALUES
('kids_base', NULL, 10, 'kc_mark', 'KC마크', 'conditional', '{"var":"cert_type","in":["safety_cert","safety_check","sdoc"]}', 'fixed', 'KC', NULL, '(인증 후 표시)', NULL),
('kids_base', NULL, 11, 'cert_no', '안전인증번호·안전확인신고번호', 'conditional', '{"var":"cert_type","in":["safety_cert","safety_check"]}', 'form', NULL, '인증서·신고확인증의 번호', '(인증 후 발급번호 기재)', NULL),
('kids_base', NULL, 20, 'product_name', '제품명', 'required', NULL, 'form', NULL, '판매할 때 쓰는 이름', NULL, NULL),
('kids_base', NULL, 30, 'model_name', '모델명', 'required', NULL, 'form', NULL, '제조자가 정한 모델명', '(모델명 확정 후 기재)', NULL),
('kids_base', NULL, 35, 'age', '사용연령', 'required', NULL, 'form', NULL, '예: 만 3세 이상 / 만 8세 이상', NULL, NULL),
('kids_base', NULL, 40, 'mfg_date', '제조년월', 'required', NULL, 'form', NULL, '예: 2026년 10월', '(생산 시 기재)', NULL),
('kids_base', NULL, 50, 'maker', '제조자명', 'required', NULL, 'form', NULL, '제품을 만든 회사', NULL, NULL),
('kids_base', NULL, 60, 'importer', '수입자명', 'conditional', '{"var":"is_import","eq":true}', 'form', NULL, '수입품에 한함', NULL, '수입품인 경우'),
('kids_base', NULL, 70, 'address_phone', '주소 및 전화번호', 'required', NULL, 'form', NULL, '지역번호 포함', NULL, NULL),
('kids_base', NULL, 80, 'country', '제조국명', 'conditional', '{"var":"is_import","eq":true}', 'form', NULL, '수입품에 한함', NULL, '수입품인 경우'),
('kids_base', NULL, 90, 'caution', '사용상 주의사항', 'required', NULL, 'text_block', 'caution', '어린이가 이해하기 쉬운 문구로', NULL, NULL),
('kids_base', NULL, 91, 'warning', '경고문구·안전표시', 'conditional', NULL, 'text_block', 'warning', NULL, NULL, '품목 기준에 경고문구가 있는 경우'),
('kids_base', NULL, 92, 'care', '취급상 주의사항', 'conditional', NULL, 'text_block', 'care', NULL, NULL, '품목 기준에 있는 경우'),
('kids_base', NULL, 93, 'manual', '사용설명서 기재사항', 'conditional', NULL, 'text_block', 'manual', NULL, NULL, '품목 기준에 있는 경우'),
('kids_base', NULL, 95, 'kc_notice', '안내문구', 'required', '{"var":"cert_type","in":["safety_cert","safety_check","sdoc"]}', 'fixed', 'KC마크는 이 제품이 공통안전기준에 적합하였음을 의미합니다.', '생략하려면 홈페이지 주소 등을 표시 (공통안전기준 5.8)', NULL, NULL);

INSERT INTO items (id, code, name, category, group1, group2, cert_type, base_standard, scope_text, source_doc, source_page, source_url, source_edition, notice_no, needs_standard_text, extraction, review_status) VALUES
(7001, 'K-01', '아동용 섬유제품', 'kids', '어린이제품', '아동용 섬유제품', 'sdoc', '공급자적합성확인기준 부속서 15 아동용 섬유제품 (+ 어린이제품 공통안전기준)', '피부에 직접 또는 간접 접촉하는 섬유로 만든 36개월 이상 만 13세 이하 아동용 섬유제품', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=1', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7002, 'K-02', '아동용 이단침대', 'kids', '어린이제품', '아동용 이단침대', 'safety_check', '안전확인기준 부속서 5 어린이용 이단침대 (+ 어린이제품 공통안전기준)', '만 3세 이상 만 13세 이하 가정용 2단 침대. 바닥에서 침대 바닥판까지 800 mm 이상인 1인용 침대도 포함', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=2', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7003, 'K-03', '어린이용 가구', 'kids', '어린이제품', '어린이용 가구', 'sdoc', '공급자적합성확인기준 부속서 14 어린이용 가구 (+ 어린이제품 공통안전기준)', '생후부터 13세 이하 어린이가 가정·어린이집·유치원·초등학교 등에서 사용하도록 의도된 가구', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=3', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7004, 'K-04', '어린이용 가죽제품', 'kids', '어린이제품', '어린이용 가죽제품', 'sdoc', '공급자적합성확인기준 부속서 1 어린이용 가죽제품 (+ 어린이제품 공통안전기준)', '36개월 이상 만 13세 이하 어린이가 사용하는 가죽제품 (36개월 미만은 안전확인기준 부속서 1의 세부분류)', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=4', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7005, 'K-05', '어린이용 롤러스케이트', 'kids', '어린이제품', '어린이용 롤러스케이트', 'sdoc', '공급자적합성확인기준 부속서 7 어린이용 롤러스케이트 (+ 어린이제품 공통안전기준)', '앞·뒤에 각 2개 바퀴를 병렬로 단 것으로 구두 장착부 최대 길이 180 mm 이상. 탈착식·비탈착식 신발 포함', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=5', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7006, 'K-06', '어린이용 물놀이기구', 'kids', '어린이제품', '어린이용 물놀이기구', 'safety_cert', '안전인증기준 부속서 1 어린이용 물놀이 기구 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이의 부양을 돕는 물놀이기구. 공기주입식 물놀이기구와 수영보조용품(착용형·비착용형). 에어매트리스·에어베개·비치볼처럼 물에서 쓸 우려가 있는 제품 포함', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=6', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7007, 'K-07', '어린이용 물안경', 'kids', '어린이제품', '어린이용 물안경', 'sdoc', '공급자적합성확인기준 부속서 4 어린이용 물안경 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이가 수영장 등에서 쓰는 물안경(스노클 포함). 일안식·이안식·다안식', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=7', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7008, 'K-08', '어린이용 바퀴 달린 운동화', 'kids', '어린이제품', '어린이용 바퀴 달린 운동화', 'sdoc', '공급자적합성확인기준 부속서 6 어린이용 바퀴 달린 운동화 (+ 어린이제품 공통안전기준)', '운동화 밑창에 바퀴를 달아 주행할 수 있게 한 것. 프레임 탈부착형(1개/2개 이상), 바퀴 완전 삽입형', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=8', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7009, 'K-09', '어린이용 스케이트보드', 'kids', '어린이제품', '어린이용 스케이트보드', 'safety_check', '안전확인기준 부속서 4 어린이용 스케이트보드 (+ 어린이제품 공통안전기준)', '체중 20 kg을 초과하는 탑승자가 혼자 힘으로 가속·조정하는 스케이트보드', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=9', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7010, 'K-10', '어린이용 스키용구', 'kids', '어린이제품', '어린이용 스키용구', 'sdoc', '공급자적합성확인기준 부속서 8 어린이용 스키용구 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이용 알파인 스키, 스키화(합성수지제), 스키바인딩', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=10', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7011, 'K-11', '어린이용 스포츠 보호용품', 'kids', '어린이제품', '어린이용 스포츠 보호용품', 'safety_check', '안전확인기준 부속서 3 어린이용 스포츠 보호용품(보호장구 및 안전모) (+ 어린이제품 공통안전기준)', '어린이가 스포츠·레저 활동 중 상해를 막는 보호장구(롤러스포츠용: 손·손목·팔꿈치·무릎)와 어린이용 안전모', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=11', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7012, 'K-12', '어린이용 안경테 및 선글라스', 'kids', '어린이제품', '어린이용 안경테 및 선글라스', 'sdoc', '공급자적합성확인기준 부속서 3 어린이용 안경테 및 선글라스 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이가 사용하는 안경테 및 선글라스', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=12', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7013, 'K-13', '어린이용 온열팩', 'kids', '어린이제품', '어린이용 온열팩', 'safety_check', '안전확인기준 부속서 15 어린이용 온열팩 (+ 어린이제품 공통안전기준)', '불·전기 등 외부 에너지 없이 내장 성분의 화학 반응으로 데워지는 만 13세 이하 어린이용 온열용품', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=13', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7014, 'K-14', '어린이용 우산 및 양산', 'kids', '어린이제품', '어린이용 우산 및 양산', 'sdoc', '공급자적합성확인기준 부속서 5 어린이용 우산 및 양산 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이용 우산·양산·겸용 (캐릭터 우산 등)', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=14', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7015, 'K-15', '어린이용 자전거', 'kids', '어린이제품', '어린이용 자전거', 'safety_check', '안전확인기준 부속서 9 어린이용 자전거 (+ 어린이제품 공통안전기준)', '어린이·유아용 이륜자전거로 안장 최대 높이 435 mm 초과 635 mm 미만', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=15', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7016, 'K-16', '어린이용 장신구', 'kids', '어린이제품', '어린이용 장신구', 'sdoc', '공급자적합성확인기준 부속서 11 어린이용 장신구 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이가 장식용으로 착용하는 반지·목걸이·팔찌·귀고리·펜던트·발찌·손톱장식·피어싱·머리장식·어린이용 시계·미아방지 팔찌 등. 재질: 섬유·플라스틱·금속(도금)·목·가죽', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=16', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7017, 'K-17', '어린이용 킥보드', 'kids', '어린이제품', '어린이용 킥보드', 'sdoc', '공급자적합성확인기준 부속서 12 어린이용 킥보드 (+ 어린이제품 공통안전기준)', '바퀴 2개 이상, 발판과 핸들이 있고 좌석 없이 발로 차서 가는 이동기구. 근력식과 전동식 모두 포함', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=17', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7018, 'K-18', '완구', 'kids', '어린이제품', '완구', 'safety_check', '안전확인기준 부속서 6 완구 (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이가 놀이에 쓰도록 고안된 제품. 활동·미술공예·퍼즐·파티·봉제인형·기능성·게임·승용·발사체·역할놀이·악기·운동·유아·블록·모형·자석·조종·가구·교육용·조립·기타 완구', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=18', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7019, 'K-19', '유모차', 'kids', '어린이제품', '유모차', 'safety_check', '안전확인기준 부속서 13 유모차 (+ 어린이제품 공통안전기준)', '15 kg 이하 유아 1명 이상 좌석(20 kg까지 플랫폼 포함)을 가진 바퀴 달린 이동수단(휴대용 포함)', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=19', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7020, 'K-20', '유아용 삼륜차', 'kids', '어린이제품', '유아용 삼륜차', 'safety_check', '안전확인기준 부속서 7 유아용 삼륜차 (+ 어린이제품 공통안전기준)', '만 6개월부터 주로 5세 이하 유아가 페달을 돌려 타는 발판식 삼륜차', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=20', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7021, 'K-21', '유아용 섬유제품', 'kids', '어린이제품', '유아용 섬유제품', 'safety_check', '안전확인기준 부속서 1 유아용 섬유제품 (+ 어린이제품 공통안전기준)', '36개월 미만 영·유아용 섬유제품 (의류, 침구, 신발, 양말, 장갑, 모자, 가방, 신생아용품 등)', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=21', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7022, 'K-22', '유아용 의자', 'kids', '어린이제품', '유아용 의자', 'safety_check', '안전확인기준 부속서 8 유아용 의자 (+ 어린이제품 공통안전기준)', '6개월~36개월 유아가 식사용으로 쓰는 높은 의자, 부스터 의자, 테이블부착식 의자', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=22', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7023, 'K-23', '유아용 침대', 'kids', '어린이제품', '유아용 침대', 'safety_check', '안전확인기준 부속서 14 유아용 침대 (+ 어린이제품 공통안전기준)', '가정용 요람(기울어진 요람 포함), 유아용 침대(시소식·그네식·전동식 간이침대 포함), 접이식 침대, 놀이 울타리. 다른 품목으로 전환 가능한 침대 포함', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=23', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7024, 'K-24', '유아용 캐리어', 'kids', '어린이제품', '유아용 캐리어', 'safety_check', '안전확인기준 부속서 16 유아용 캐리어 (+ 어린이제품 공통안전기준)', '유아를 업거나 안기 위해 성인 상체에 부착하는 캐리어. 프레임 없는(포대기·슬링·힙시트 포함)·프레임 있는', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=24', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed'),
(7025, 'K-25', '자동차용 어린이보호장치', 'kids', '어린이제품', '자동차용 어린이보호장치', 'safety_cert', '안전인증기준 부속서 3 자동차용 어린이보호장치 (+ 어린이제품 공통안전기준)', '자동차 사고 등에서 어린이를 앉히거나 뉘어 구속·고정하는 장치', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=25', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7026, 'K-26', '학용품', 'kids', '어린이제품', '학용품', 'safety_check', '안전확인기준 부속서 11 학용품 (+ 어린이제품 공통안전기준)', '학교·가정에서 학습용으로 쓰는 크레용·크레파스, 연필류, 샤프, 지우개, 파스텔, 그림물감, 분필, 마킹펜, 연필깎이, 필통, 색종이, 공책, 스케치북, 문구용 풀, 악기류', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=26', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7027, 'K-27', '합성수지제 어린이용품', 'kids', '어린이제품', '합성수지제 어린이용품', 'safety_check', '안전확인기준 부속서 2 합성수지제 어린이용품 (+ 어린이제품 공통안전기준)', '어린이용 침대가드(18~60개월), 유아용 노리개젖꼭지, 노리개젖꼭지 걸이, 합성수지 바닥매트(돗자리형·폴더형·퍼즐형)', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=27', '2026-10-01 열람본', NULL, 1, 'manual', 'unreviewed'),
(7028, 'K-28', '기타 어린이제품', 'kids', '어린이제품', '기타 어린이제품', 'sdoc', '어린이제품 공통안전기준 (개별 안전기준 없음) (+ 어린이제품 공통안전기준)', '만 13세 이하 어린이가 사용하거나 어린이를 위해 사용되는 물품 중 개별 안전기준이 없는 공급자적합성확인대상. 어린이에게 닿지 않는 구성 부분은 제외', 'safetyguide.kr 표시사항가이드 (어린이제품)', NULL, 'https://www.safetyguide.kr/indct/kid?id=28', '2026-10-01 열람본', NULL, 0, 'manual', 'unreviewed');

INSERT INTO item_templates (item_id, template_code) VALUES
(7001, 'kids_base'),
(7002, 'kids_base'),
(7003, 'kids_base'),
(7004, 'kids_base'),
(7005, 'kids_base'),
(7006, 'kids_base'),
(7007, 'kids_base'),
(7008, 'kids_base'),
(7009, 'kids_base'),
(7010, 'kids_base'),
(7011, 'kids_base'),
(7012, 'kids_base'),
(7013, 'kids_base'),
(7014, 'kids_base'),
(7015, 'kids_base'),
(7016, 'kids_base'),
(7017, 'kids_base'),
(7018, 'kids_base'),
(7019, 'kids_base'),
(7020, 'kids_base'),
(7021, 'kids_base'),
(7022, 'kids_base'),
(7023, 'kids_base'),
(7024, 'kids_base'),
(7025, 'kids_base'),
(7026, 'kids_base'),
(7027, 'kids_base'),
(7028, 'kids_base');

INSERT INTO item_aliases (item_id, alias) VALUES
(7001, '아동복'),
(7001, '아동 의류'),
(7002, '이층침대'),
(7002, '2층 침대'),
(7002, '벙커침대'),
(7003, '어린이 책상'),
(7003, '어린이 의자'),
(7003, '학생 책상'),
(7004, '어린이 가죽 신발'),
(7004, '어린이 가죽 가방'),
(7006, '튜브'),
(7006, '암링'),
(7006, '수영조끼'),
(7006, '킥판'),
(7006, '비치볼'),
(7008, '힐리스'),
(7011, '어린이 헬멧'),
(7011, '어린이 보호대'),
(7013, '어린이 핫팩'),
(7014, '어린이 우산'),
(7014, '캐릭터 우산'),
(7015, '어린이 자전거'),
(7015, '유아 자전거'),
(7016, '어린이 머리핀'),
(7016, '어린이 목걸이'),
(7016, '미아방지 팔찌'),
(7017, '어린이 킥보드'),
(7017, '유아 킥보드'),
(7018, '장난감'),
(7018, '블록'),
(7018, '인형'),
(7018, '봉제인형'),
(7018, '퍼즐'),
(7018, '모빌'),
(7018, '딸랑이'),
(7018, '치아발육기'),
(7019, '유아차'),
(7019, '휴대용 유모차'),
(7020, '세발자전거'),
(7020, '유아 세발자전거'),
(7021, '유아복'),
(7021, '아기 옷'),
(7021, '배냇저고리'),
(7021, '아기 이불'),
(7021, '턱받이'),
(7022, '하이체어'),
(7022, '아기 식탁의자'),
(7022, '부스터'),
(7023, '아기 침대'),
(7023, '요람'),
(7023, '바운서'),
(7023, '놀이 울타리'),
(7023, '범퍼침대'),
(7024, '아기띠'),
(7024, '포대기'),
(7024, '슬링'),
(7024, '힙시트'),
(7025, '카시트'),
(7025, '유아 카시트'),
(7025, '부스터 시트'),
(7025, '주니어 카시트'),
(7026, '크레파스'),
(7026, '크레용'),
(7026, '색연필'),
(7026, '연필'),
(7026, '지우개'),
(7026, '물감'),
(7026, '필통'),
(7026, '스케치북'),
(7026, '연필깎이'),
(7026, '사인펜'),
(7027, '노리개젖꼭지'),
(7027, '쪽쪽이'),
(7027, '공갈젖꼭지'),
(7027, '침대가드'),
(7027, '놀이매트'),
(7027, '퍼즐매트'),
(7027, '바닥매트');

-- 품목별 "추가" 항목 ([..] 조건 → condition_text)
INSERT INTO label_fields (template_code, item_id, sort_order, field_key, display_name, requirement, show_if, source, source_key, form_help, placeholder_text, condition_text) VALUES
(NULL, 7001, 101, 'extra_1', '취급상 주의표시', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7002, 101, 'extra_1', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7003, 101, 'extra_1', '마감재', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7003, 102, 'extra_2', '구조부재', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7003, 103, 'extra_3', '표면가공', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7003, 104, 'extra_4', '쿠션재', 'conditional', '{"var":"furniture_type","in":["chair","sofa","bed"]}', 'form', NULL, NULL, NULL, '의자·소파·매트리스와 함께 있는 경우에 한함'),
(NULL, 7003, 105, 'extra_5', '크기·체중의 한계', 'conditional', NULL, 'form', NULL, NULL, NULL, '크기·체중 제한이 있는 경우'),
(NULL, 7005, 101, 'extra_1', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7006, 101, 'extra_1', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7006, 102, 'extra_2', '사용 재료명·치수(내경×외경)', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7006, 103, 'extra_3', '정보 및 경고문구', 'conditional', '{"var":"water_toy_type","in":["aid_wear","aid_hold"]}', 'form', NULL, NULL, NULL, '수영보조용품에 한함'),
(NULL, 7007, 101, 'extra_1', '크기·체중의 한계', 'conditional', NULL, 'form', NULL, NULL, NULL, '해당하는 경우'),
(NULL, 7008, 101, 'extra_1', '신발의 치수', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7009, 101, 'extra_1', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7010, 101, 'extra_1', '호칭길이', 'conditional', '{"var":"ski_type","eq":"ski"}', 'form', NULL, NULL, NULL, '스키에 한함'),
(NULL, 7010, 102, 'extra_2', '신발의 크기', 'conditional', '{"var":"ski_type","eq":"boot"}', 'form', NULL, NULL, NULL, '스키화에 한함'),
(NULL, 7011, 101, 'extra_1', '보호장구의 크기', 'conditional', '{"var":"protector_type","eq":"pad"}', 'form', NULL, NULL, NULL, '보호장구에 한함'),
(NULL, 7011, 102, 'extra_2', '보호부분 (좌·우 구분 포함)', 'conditional', '{"var":"protector_type","eq":"pad"}', 'form', NULL, NULL, NULL, '보호장구에 한함'),
(NULL, 7011, 103, 'extra_3', '보호수준', 'conditional', '{"var":"protector_type","eq":"pad"}', 'form', NULL, NULL, NULL, '보호장구에 한함'),
(NULL, 7011, 104, 'extra_4', '크기의 호칭', 'conditional', '{"var":"protector_type","eq":"helmet"}', 'form', NULL, NULL, NULL, '안전모에 한함'),
(NULL, 7011, 105, 'extra_5', '투시부의 재질', 'conditional', '{"var":"helmet_visor","eq":"yes"}', 'form', NULL, NULL, NULL, '눈 보호구에 한함'),
(NULL, 7012, 101, 'extra_1', '재질 (테·렌즈)', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7012, 102, 'extra_2', 'UV-A 차단율(%)', 'conditional', '{"all":[{"var":"eyewear_type","eq":"sunglasses"},{"var":"uv_separate","eq":"yes"}]}', 'form', NULL, NULL, NULL, '선글라스'),
(NULL, 7012, 103, 'extra_3', 'UV-B 차단율(%)', 'conditional', '{"all":[{"var":"eyewear_type","eq":"sunglasses"},{"var":"uv_separate","eq":"yes"}]}', 'form', NULL, NULL, NULL, '선글라스'),
(NULL, 7012, 104, 'extra_4', '자외선 차단율(%)', 'conditional', '{"all":[{"var":"eyewear_type","eq":"sunglasses"},{"var":"uv_separate","eq":"no"}]}', 'form', NULL, NULL, NULL, 'UV-A·B를 각각 표시할 수 없는 경우'),
(NULL, 7012, 105, 'extra_5', '가시광선 투과율(%)', 'conditional', '{"var":"eyewear_type","eq":"sunglasses"}', 'answer', 'visible_transmittance', NULL, NULL, '선글라스'),
(NULL, 7012, 106, 'extra_6', '필터범주 (기호 및/또는 문구)', 'conditional', '{"var":"eyewear_type","eq":"sunglasses"}', 'form', NULL, NULL, NULL, '선글라스'),
(NULL, 7012, 107, 'extra_7', '색상 (제품에 표시)', 'conditional', '{"var":"eyewear_type","eq":"sunglasses"}', 'form', NULL, NULL, NULL, '선글라스 제품 본체'),
(NULL, 7012, 108, 'extra_8', '렌즈삽입부 크기□렌즈간 거리 (전면부 또는 다리)', 'conditional', '{"var":"eyewear_type","eq":"sunglasses"}', 'form', NULL, NULL, NULL, '선글라스 제품 본체'),
(NULL, 7012, 109, 'extra_9', '다리의 전체 길이 (다리)', 'conditional', '{"var":"eyewear_type","eq":"sunglasses"}', 'form', NULL, NULL, NULL, '선글라스 제품 본체'),
(NULL, 7013, 101, 'extra_1', '지속시간', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7013, 102, 'extra_2', '최고온도', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7015, 101, 'extra_1', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7016, 101, 'extra_1', '재질', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7017, 101, 'extra_1', '한계하중', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7017, 102, 'extra_2', '"만8세 이상만 사용하시오"', 'conditional', '{"var":"kick_handbrake","eq":"no"}', 'fixed', '만8세 이상만 사용하시오', NULL, NULL, '핸드브레이크가 없는 제품'),
(NULL, 7018, 101, 'extra_1', '크기·체중의 한계', 'conditional', '{"var":"has_weight_limit","eq":"yes"}', 'form', NULL, NULL, NULL, '크기·체중 제한이 있는 완구'),
(NULL, 7018, 102, 'extra_2', '제품 낱개: 제조(수입)자명 또는 약호, 안전표시, 지시사항', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7019, 101, 'extra_1', '종류', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7019, 102, 'extra_2', '섬유의 조성', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7019, 103, 'extra_3', '크기·체중의 한계', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7020, 101, 'extra_1', '한계체중', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7021, 101, 'extra_1', '섬유의 조성 또는 혼용률', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7021, 102, 'extra_2', '충전재 조성', 'conditional', '{"var":"filling","in":["down","other"]}', 'form', NULL, NULL, NULL, '충전재를 사용한 제품에 한함'),
(NULL, 7021, 103, 'extra_3', '치수(cm)', 'conditional', NULL, 'form', NULL, NULL, NULL, '숄·가방·커튼 등 일부 제품은 생략'),
(NULL, 7021, 104, 'extra_4', '방염여부', 'conditional', '{"var":"sleeping_bag_carpet","eq":"yes"}', 'form', NULL, NULL, NULL, '침낭, 카페트'),
(NULL, 7021, 105, 'extra_5', '유해물질 안전요건 적합 문구', 'required', NULL, 'fixed', '기준에서 정한 유해물질 안전요건에 적합한 제품임', NULL, NULL, NULL),
(NULL, 7022, 101, 'extra_1', '한계체중', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7023, 101, 'extra_1', '한계체중', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7023, 102, 'extra_2', '적정인원수', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7023, 103, 'extra_3', '사용기간', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7023, 104, 'extra_4', '매트리스 최대 높이·두께 표시선 (제품에 영구 표시)', 'conditional', '{"var":"crib_type","in":["crib","large"]}', 'form', NULL, NULL, NULL, '유아용 침대·요람'),
(NULL, 7024, 101, 'extra_1', '종류', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7024, 102, 'extra_2', '한계체중', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7025, 101, 'extra_1', '종류', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7025, 102, 'extra_2', '사용 가능한 어린이의 체중 범위', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7025, 103, 'extra_3', '사용범주 및 구속방법', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7025, 104, 'extra_4', '구속형태', 'required', NULL, 'form', NULL, NULL, NULL, NULL),
(NULL, 7027, 101, 'extra_1', '재질', 'conditional', '{"var":"resin_type","in":["pacifier","holder"]}', 'form', NULL, NULL, NULL, '노리개젖꼭지·걸이'),
(NULL, 7027, 102, 'extra_2', '크기·체중의 한계', 'conditional', '{"var":"resin_type","eq":"guard"}', 'form', NULL, NULL, NULL, '침대가드'),
(NULL, 7028, 101, 'extra_1', '크기·체중의 한계(한계하중)', 'conditional', '{"var":"has_weight_limit","eq":"yes"}', 'form', NULL, NULL, NULL, '제한이 있는 경우');

INSERT INTO text_blocks (item_id, code, variant, show_if, title, lines, needs_review) VALUES
(7001, 'caution', 'default', '{"var":"small_parts","eq":"yes"}', '주의사항 (작은 부품)', '["작은 부품이 부착된 경우의 주의사항 (부속서 15의 7.2) — 원문 확인"]', 1),
(7001, 'caution', 'default', '{"var":"soft_resin_shoes","eq":"yes"}', '주의사항 (연질·발포 합성수지 신발)', '["연질 또는 발포 합성수지 신발 주의사항 (부속서 15의 7.2) — 원문 확인"]', 1),
(7001, 'display_method', 'default', NULL, '표시 방법', '["공통안전기준 표시사항은 제품 표면 또는 최소 포장단위에 한글로, 쉽게 지워지거나 떨어지지 않게 표시","사용상 주의사항·사용설명서는 어린이가 이해하기 쉬운 문구로"]', 0),
(7001, 'source_note', 'default', NULL, '원문 오류·주의', '["표시 예시에 섬유 조성·치수가 없고 작성요령은 부속서 15의 7로 넘김. 유아용 섬유제품(K-21)과 같은 수준의 조성·치수 표시가 필요한지 원문 확인"]', 1),
(7002, 'manual', 'default', NULL, '사용설명서 (부속서 5의 6.2)', '["매트리스 상단이 침대에 표시된 선 위로 올라가지 않도록 하는 설명","(원문 7줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7002, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 5의 6.1.8 원문에서 문구 확인"]', 1),
(7002, 'display_method', 'default', NULL, '표시 방법', '["사용상 주의사항(경고문구)은 제품 본체에 부착하고 위치·내용·형태를 눈에 띄게","사용설명서를 부착·제공해야 함"]', 0),
(7003, 'care', 'default', NULL, '취급상 주의사항 (해당 없는 것이 명백하면 생략·변경 가능)', '["직사광선 또는 열을 피할 것","(원문 11줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7003, 'warning', 'default', '{"var":"small_parts","eq":"yes"}', '작은 부품이 있는 가구', '["경고 문구 또는 기호로 표시","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7003, 'display_method', 'default', NULL, '표시 방법', '["제품 또는 최소단위 포장마다 보기 쉬운 곳에 한글로 표시"]', 0),
(7003, 'source_note', 'default', NULL, '원문 오류·주의', '["표시 예시 수입자명이 \"아동용섬유제품나라\"로 다른 품목에서 복사됨(예시값이라 영향 없음)"]', 1),
(7004, 'source_note', 'default', NULL, '원문 오류·주의', '["세부 분기(연령 → 형태 → 소재·동물명 → 안감·밑창 → 수입 여부)는 분기설계 본문 7.2에 있으며 이 SQL에는 아직 넣지 않음","세부분류 표가 섬유제품 표를 복사한 것","사용연령 작성요령(3세·8세 구간)과 \"학생용 의자\" 주석이 가구 페이지에서 복사됨","주의사항 번호 \"4.1 인조가죽\"은 3.2가 맞음","\"기타 가죽제품\" 주의사항 본문 없음"]', 1),
(7005, 'manual', 'default', NULL, '사용설명서 (부속서 7의 6.3)', '["별도 조립 부품이 있으면 조립 요령, 사이즈 맞추는 방법, 보관방법 등"]', 0),
(7005, 'caution', 'default', NULL, '사용상 주의사항', '["부속서 7의 6.2 원문 확인 필요"]', 1),
(7005, 'display_method', 'default', NULL, '표시 방법', '["사용상 주의사항은 제품·포장 외 한글 사용설명서에 별도 표시 가능"]', 0),
(7005, 'source_note', 'default', NULL, '원문 오류·주의', '["작성요령에 방한용 마스크 문장이 섞여 있음(섬유제품 페이지에서 복사)"]', 1),
(7006, 'caution', 'default', '{"var":"water_toy_type","eq":"inflatable"}', '사용상 주의사항 (공기주입 물놀이기구)', '["공기주입 물놀이기구는 구명기구가 아니며 수영장이나 풀장 등 안전한 곳에서만 사용하시오","(원문 7줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7006, 'caution', 'default', '{"var":"water_toy_type","in":["aid_wear","aid_hold"]}', '사용상 주의사항 (수영보조용품)', '["공기를 주입하는 수영보조용품에 공기를 주입하는 방법, 공기를 제거하는 방법, 잠금장치의 사용법","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7006, 'warning', 'default', '{"var":"water_toy_type","eq":"inflatable"}', '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 1의 제1부 7.1.8 원문에서 문구 확인"]', 1),
(7006, 'warning', 'default', '{"var":"water_toy_type","eq":"aid_wear"}', '경고문구·정보 및 경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 1의 제2부 8.3.8, 8.3.9, 9.5 원문에서 문구 확인"]', 1),
(7006, 'warning', 'default', '{"var":"water_toy_type","eq":"aid_hold"}', '경고문구·정보 및 경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 1의 제3부 8.3.7, 8.3.9, 9.4 원문에서 문구 확인"]', 1),
(7006, 'display_method', 'default', NULL, '표시 방법', '["모델명·제조년월·제조자·수입자·제조국명·사용연령·체중범위는 반드시 제품에 표시","재료명, 치수, 사용상 주의사항은 한글 사용설명서에 별도 표시 가능","수영보조용품은 모든 표면에 표시라벨, 공기 넣는 제품은 주입 밸브 100 mm 이내에 경고","경고 제목은 5 mm 이상, 내용은 3 mm 이상 문자로 인쇄 또는 양각"]', 0),
(7007, 'caution', 'default', NULL, '사용상 주의사항', '["피부에 닿는 부분에 알레르기 반응이 있을 수 있으니 주의하시오"]', 0),
(7007, 'display_method', 'default', NULL, '표시 방법', '["알레르기 주의사항은 포장·설명서 등으로 반드시 표시하고 눈에 띄게"]', 0),
(7008, 'caution', 'default', NULL, '사용상 주의사항', '["탑승자와 다른 사람에게 사고의 우려가 있는 포장도로나 차도에서는 타지 마시오.","(원문 5줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7008, 'manual', 'default', NULL, '사용설명서', '["경고문구","(원문 6줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7008, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 6의 6.2.1.1 원문에서 문구 확인"]', 1),
(7008, 'display_method', 'default', NULL, '표시 방법', '["제품 본체에는 경고·주의 문구를 적색글씨·음양각·큰 글씨 등으로 구별되게"]', 0),
(7009, 'manual', 'default', NULL, '사용설명서', '["경고문구","(원문 5줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7009, 'caution', 'default', NULL, '사용상 주의사항', '["부속서 4의 9.2 원문 확인 필요"]', 1),
(7009, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 4의 9.2.2 원문에서 문구 확인"]', 1),
(7009, 'source_note', 'default', NULL, '원문 오류·주의', '["표시 예시 첫 칸이 \"안전인증번호\"로 되어 있으나 안전확인 품목이라 안전확인신고번호가 맞음"]', 1),
(7010, 'caution', 'default', '{"var":"ski_type","eq":"ski"}', '사용상 주의사항 (스키)', '["사용 후에는 물기를 제거한 후 보관할 것","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7010, 'caution', 'default', '{"var":"ski_type","eq":"boot"}', '사용상 주의사항 (스키화)', '["발에 꼭 맞는 스키화를 선택할 것(신어보고 몸을 앞으로 기울였을 때 뒷부분에 손가락 하나가 들어갈 정도의 공백이 남는 것이 좋다)","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7010, 'manual', 'default', '{"var":"ski_type","eq":"binding"}', '사용설명서 및 장착설명서 (바인딩)', '["부속서 8의 7.3.6 및 7.3.7에 따름. 판매점에서 배포, 모든 스키어가 알기 쉬운 설명서 첨부 — 원문 확인"]', 1),
(7010, 'display_method', 'default', NULL, '표시 방법', '["주소·전화번호는 제품 또는 최소포장 등에 별도 표시 가능","사용상 주의사항은 포장상자 또는 동봉 설명서에 포함"]', 0),
(7010, 'source_note', 'default', NULL, '원문 오류·주의', '["작성요령이 호칭길이를 \"안전확인기준 부속서 8의 3.1\"로 적었으나 이 품목은 공급자적합성확인기준 부속서 8"]', 1),
(7011, 'caution', 'default', '{"var":"protector_type","eq":"pad"}', '사용상 주의사항 (보호장구)', '["세탁방법","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7011, 'caution', 'default', '{"var":"protector_type","eq":"helmet"}', '사용상 주의사항 (안전모)', '["안전모는 머리에 잘 맞고 올바르게 착용해야만 보호기능을 수행할 수 있습니다.","(원문 7줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7011, 'warning', 'default', '{"var":"protector_type","eq":"helmet"}', '경고문구 (안전모)', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 3의 7.1.12 원문에서 문구 확인"]', 1),
(7011, 'source_note', 'default', NULL, '원문 오류·주의', '["제품특징의 \"만 3세 이하\"는 \"만 13세 이하\"의 오기로 보임"]', 1),
(7012, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 3의 5.2.9, 5.2.10 원문에서 문구 확인"]', 1),
(7012, 'display_method', 'default', NULL, '표시 방법', '["낱개포장 또는 꼬리표에 한글 인쇄, 꼬리표는 떨어지지 않게","제품 본체 표시는 각인·인쇄 원칙, 불가하면 떨어지지 않는 스티커"]', 0),
(7013, 'caution', 'default', NULL, '사용상 주의사항', '["저온 화상에 주의","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7013, 'caution', 'default', '{"var":"stick_type","eq":"yes"}', '사용상 주의사항 (붙이는 타입)', '["붙이는 타입에서는 직접 살에 붙이지 않도록 주의"]', 0),
(7013, 'display_method', 'default', NULL, '표시 방법', '["의료기기로 오인될 수 있는 표현 금지","해당 없는 항목은 생략하거나 적절한 용어로 변경 가능"]', 0),
(7014, 'caution', 'default', NULL, '사용상 주의사항', '["공통안전기준 5.7에 따름: 제품 특성에 맞게 작성 — 원문 확인"]', 1),
(7014, 'display_method', 'default', NULL, '표시 방법', '["제품 또는 최소단위 포장에 한글 스티커·꼬리표 등으로 인쇄 표시"]', 0),
(7014, 'source_note', 'default', NULL, '원문 오류·주의', '["안내문구 작성요령의 \"공통안전기준 5.\"는 5.8의 오기"]', 1),
(7015, 'caution', 'default', NULL, '사용상 주의사항·사용설명서 (부속서 9의 6.2)', '["자전거가 설계된 용도의 유형(사용이 적합한 지형의 종류), 잘못된 사용으로 인한 위험 경고","(원문 22줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7015, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 9의 6.1.7 원문에서 문구 확인"]', 1),
(7015, 'display_method', 'default', NULL, '표시 방법', '["제품에 잘 보이는 곳에 지워지지 않게 한글로","사용설명서·주의사항은 한글로 제공"]', 0),
(7016, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 11의 7.10 원문에서 문구 확인"]', 1),
(7017, 'caution', 'default', NULL, '사용상 주의사항', '["킥보드 사용 시 안전보호장구(헬멧, 무릎 및 팔꿈치보호대, 손목보호대 등)를 착용한 후 탈 것","(원문 6줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7017, 'manual', 'default', NULL, '사용설명서', '["사용 전 안전상태 확인","(원문 5줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7017, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 12의 8.2.1 원문에서 문구 확인"]', 1),
(7017, 'display_method', 'default', NULL, '표시 방법', '["제품 및 최소 포장단위(손잡이·발판 포함) 보기 쉬운 곳에 표시"]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"small_parts"}', '안전표시 (작은 완구 또는 작은 부품이 있는 완구)', '["\"경고! 3세 미만의 어린이는 사용할 수 없음. 작은 부품을 포함하고 있음\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"balloon"}', '안전표시 (풍선)', '["\"경고! 8세 미만의 어린이는 부풀리지 않은 풍선 또는 터진 풍선에 의해 기도가 막혀 질식할 수 있음. 성인의 통제를 요함. 부풀리지 않은 풍선을 어린이의 손에 …","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"small_ball"}', '안전표시 (작은 공 또는 구슬)', '["\"이 완구는 질식의 위험이 있는 작은 공(구슬)으로 되어 있음(을 포함하고 있음). 3세 미만의 어린이는 사용할 수 없음.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"water"}', '안전표시 (물놀이 완구)', '["\"경고! 어린이의 키가 닿는 물에서만 보호자의 감시 하에서 사용되어야 함\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"crib_mobile"}', '안전표시 (유아 침대용 완구, 모빌, 크립짐)', '["어린이가 무릎이나 손을 폈을 때 완구를 치우지 않으면 얽히거나 목이 졸릴 수 있음을 경고하는 문구","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"food_contact"}', '안전표시 (음식과 접촉하는 완구)', '["제품의 사용 전후에 충분히 세척하도록 경고하는 문구 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"adult_assembly"}', '안전표시 (성인이 조립해야 하는 완구)', '["성인이 조립해야 한다는 내용을 포장에 기술","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"mock_protective"}', '안전표시 (모조 보호 장구)', '["\"경고! 사고발생 시 보호받지 못함\" 또는 \"경고! 자외선으로부터 보호받지 못함\"","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"sharp_function"}', '안전표시 (기능성 가장자리와 끝)', '["날카로운 가장자리 또는 끝이 있음을 제품 또는 포장에 표시 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"functional"}', '안전표시 (기능 완구)', '["\"경고! 어른의 직접적인 감시하에서 사용되어야만 함\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"toy_skate"}', '안전표시 (완구 롤러스케이트와 완구 스케이트보드)', '["\"경고! 안전모 및 손목 보호대 등의 보호장구를 착용하여야 함.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"projectile"}', '안전표시 (발사체 완구)', '["\"경고! 눈이나 얼굴 쪽으로 겨누지 말 것.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"kite"}', '안전표시 (완구 연)', '["\"경고! 천둥 번개시 또는 전압선 근처에서는 사용을 금함\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"toy_bike"}', '안전표시 (완구 자전거)', '["\"경고! 안전모 등 보호장구를 착용하고 탈 것.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"cap"}', '안전표시 (격발 장치)', '["\"경고! 실내에서 사용하지 말 것. 눈이나 귀 부근에서 사용하지 말 것. 주머니에 격발뇌관이 흔들리게끔 갖고 다니지 말 것.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"loud"}', '안전표시 (순간적으로 높은 소리를 내는 완구)', '["\"경고! 귀에 가까이 대고 사용하지 말 것. 잘못 사용시에는 청력이 손상될 수 있음.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"mouth"}', '안전표시 (유아가 입에 넣을 수 있도록 의도된 완구)', '["\"경고! 입에 넣으면 프탈레이트계 가소제가 용출될 수 있으니 입에 넣지 말 것.\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"long_fiber"}', '안전표시 (단섬유를 포함하는 완구)', '["\"주의! 긴 털로 인하여 10 개월 미만의 어린이에게는 부적합함\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"pull_toy"}', '안전표시 (승용 목적이 아닌 끄는 완구)', '["타지 않도록 주의 표시 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"ride_on"}', '안전표시 (타는 것을 목적으로 하는 완구)', '["언덕길에서 사용금지","(원문 5줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"power_ride"}', '안전표시 (전동 승용 완구)', '["상해 위험을 줄이기 위해 보호자의 감시 하에 사용. 자동차가 있는 길거리, 가파른 경사·계단, 수영장·물 근처 사용 금지. 신발 착용, ___인 이상 탑승 금지","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"cord_power"}', '안전표시 (전등선을 사용한 완구)', '["정격 소비전력 및 정격 전압을 사용할 것 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"battery"}', '안전표시 (건전지를 사용하는 완구)', '["제품에 극성을 표시할 것"]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"heat"}', '안전표시 (열을 내는 제품)', '["열발생에 따른 주의사항을 표시할 것 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"adhesive"}', '안전표시 (접착제 및 용제)', '["사용상 주의사항, 안전 관련 사항, 피부접촉·삼켰을 때의 응급조치 사항 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"liquid"}', '안전표시 (액체를 포함하는 완구)', '["\"주의! 입에 넣거나 빨지 말 것\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"with_food"}', '안전표시 (식품을 포함하고 있는 완구)', '["\"경고. 완구를 포함하고 있음. 보호자의 감시하에서 사용되어야 함\" (원문 그대로. \"식품을 포함\"의 오기로 보임)","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"toy_box"}', '안전표시 (완구 상자)', '["설명서: 조립·관리 방법, 덮개 지지 장치 미설치 시 위험과 확인 방법 — 원문 확인"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"liquid_teether"}', '안전표시 (액체를 채운 치아 발육기)', '["\"가정용 냉장고의 냉동실에 놓아두면 안됨\""]', 0),
(7018, 'warning', 'default', '{"var":"toy_features","has":"scooter20"}', '안전표시 (완구 스쿠터 20 kg)', '["\"최대 20 kg\"","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"scooter50"}', '안전표시 (완구 스쿠터 50 kg)', '["\"최대 50 kg\"","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"magnet_kit"}', '안전표시 (자성/전기 실험 세트)', '["\"경고! 8세 미만의 어린이에게는 적합하지 않음. 이 제품은 작은 자석(들)을 포함하고 있음. 삼킨 자석들은 장기를 사이에 두고 서로 붙어 심각한 상해를 야기할 …"]', 1),
(7018, 'warning', 'default', '{"var":"toy_features","has":"toy_gun"}', '안전표시 (완구총기류)', '["총구 끝 진한(밝은) 오렌지색 마개(6 mm 이상 들어가지 않게)와 오렌지색 밴드, 외부 표면 밝은 색 채색 (표시가 아니라 구조 요건)"]', 0),
(7018, 'manual', 'default', NULL, '사용설명서 (부속서 6의 1부 5.3)', '["안전한 사용·조립 방법 정보와 지시사항을 쉽게 읽을 수 있게, 한글로"]', 0),
(7018, 'display_method', 'default', NULL, '표시 방법', '["안전 표시는 눈에 잘 띄고 읽기 쉽고 한글로, 구매 시 볼 수 있게 제품 또는 포장에","단위 포장은 가장 눈에 띄는 전면에"]', 0),
(7019, 'care', 'default', NULL, '취급상 주의사항', '["물세탁 방법 등을 포함해 2종류 이상 표시 (부속서 13의 8.1.8.2) — 원문 확인"]', 1),
(7019, 'warning', 'default', NULL, '사용설명서 및 경고·주의문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 13의 8.2 원문에서 문구 확인"]', 1),
(7019, 'display_method', 'default', NULL, '표시 방법', '["가능하면 조립요령·취급설명서 별도 첨부"]', 0),
(7020, 'caution', 'default', NULL, '사용상 주의사항', '["유아들이 작은 부품을 삼키면 질식할 위험이 있습니다.","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7020, 'caution', 'default', '{"var":"parent_handle","eq":"yes"}', '사용상 주의사항 (보호자 손잡이 봉)', '["보호자용 손잡이 봉과 발판은 자기가 스스로 주행할 수 없는 유아를 위한 보조구이며, 발이 지면 및 페달에 확실하게 닿아 스스로 주행할 수 있게 되면 반드시 해체해…","(원문 3줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7020, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 7의 5.1.9 원문에서 문구 확인"]', 1),
(7020, 'display_method', 'default', NULL, '표시 방법', '["사용상 주의사항은 한글 사용설명서에 별도 표시 가능, 조립요령·취급설명서 첨부"]', 0),
(7021, 'care', 'default', NULL, '취급상 주의사항 ((1)~(6) 중 4종류 이상, 한글 또는 KS K 0021 기호)', '["(1) 물세탁 방법","(원문 6줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7021, 'care', 'default', '{"var":"metal_accessory","eq":"yes"}', '취급상 주의사항 (금속 악세사리)', '["(7) 녹 및 피부 접촉 주의사항"]', 1),
(7021, 'care', 'default', NULL, '취급상 주의사항 (해당 시)', '["(8) 불꽃주의 — 불이 옮겨붙을 가능성이 있는 제품에 한함"]', 1),
(7021, 'caution', 'default', '{"var":"small_parts","eq":"yes"}', '주의문구 (작은 부품)', '["작은 부품이 있는 제품에 대한 주의사항 (부속서 1의 8.2) — 원문 확인"]', 1),
(7021, 'caution', 'default', '{"var":"soft_resin_shoes","eq":"yes"}', '주의문구 (연질·발포 합성수지 신발)', '["연질 또는 발포 합성수지 신발 주의사항 (부속서 1의 8.3) — 원문 확인"]', 1),
(7021, 'display_method', 'default', NULL, '표시 방법', '["개별제품에 세탁해도 떨어지지 않게 박음질 등으로 표시. 곤란하면 포장·꼬리표·스티커","포장을 열지 않으면 볼 수 없는 표시는 포장에도","동일 품명 2개 이상 묶음(상하의 제외)은 최소 판매 포장 표면에 표시 가능","제조국은 기능을 부여한 자의 국가, 국산은 \"한국산\" 등","제조연월 대신 최초판매시즌·로트번호·스타일번호·바코드·QR코드 가능"]', 0),
(7021, 'source_note', 'default', NULL, '원문 오류·주의', '["\"예시는 가정용 섬유제품에 한정\"은 이 품목명(유아용 섬유제품)의 오기"]', 1),
(7022, 'caution', 'default', NULL, '사용상 주의사항', '["안전장치는 몸에 맞고 바르게 고정시킬 것","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7022, 'caution', 'default', '{"var":"infant_chair_type","eq":"booster"}', '사용상 주의사항 (부스터 의자)', '["부스터 의자는 성인용 의자에 확실히 고정된 상태에서 사용해야 하며, 등받이가 없거나 확실하게 고정하기 어려운 형태 또는 재질의 성인용 의자에는 절대로 사용하지 말…"]', 1),
(7022, 'caution', 'default', '{"var":"infant_chair_type","eq":"table"}', '사용상 주의사항 (테이블부착식 의자)', '["사용 가능한 테이블의 두께 내에서만 사용할 것","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7022, 'warning', 'default', NULL, '경고·주의문구, 사용설명서', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 8의 제1~3부 7.2, 7.2.3 원문에서 문구 확인"]', 1),
(7022, 'source_note', 'default', NULL, '원문 오류·주의', '["주의사항 \"안전장치는 몸에 맞고 바르게 고정시킬 것\"이 두 번 나옴"]', 1),
(7023, 'manual', 'default', NULL, '사용설명서', '["표제: \"경고! 장래의 참고를 위하여 보관할 것-주의 깊게 읽을 것\"","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7023, 'warning', 'default', NULL, '사용상 주의사항·경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 14의 제2~5부 5, 6 원문에서 문구 확인"]', 1),
(7023, 'source_note', 'default', NULL, '원문 오류·주의', '["개별안전기준 칸에 기준명 대신 신고번호 예시가 들어가 있음(작성요령으로 부속서 14 확인)"]', 1),
(7024, 'caution', 'default', NULL, '사용상 주의사항', '["사용 전에 제품의 상태를 확인할 것","(원문 12줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7024, 'caution', 'default', '{"var":"carrier_frame","eq":"yes"}', '사용상 주의사항 (프레임 있는 캐리어 추가)', '["유아를 캐리어에 장착하거나 해제하는 것은 앉은 상태로 행하는 것이 바람직하다. 또 다른 사람에게 도움을 받는 것이 바람직함","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7024, 'display_method', 'default', NULL, '표시 방법', '["사용상 주의사항·취급설명서는 가능하면 별도 첨부"]', 0),
(7024, 'source_note', 'default', NULL, '원문 오류·주의', '["프레임 있는 캐리어 주의사항 목록이 두 번 반복되고, 첫 목록 끝 문장에 제목이 붙어 있음"]', 1),
(7025, 'caution', 'default', NULL, '사용상 주의사항', '["본 장치를 제조자가 제시한 설명서에 따라 자동차의 안전벨트 또는 ISOFIX 장치 또는 Latch형 고정장치로 단단히 고정할 것","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7025, 'caution', 'default', '{"var":"crs_aux_belt","eq":"yes"}', '사용상 주의사항 (보조벨트)', '["\"이 보호장치는 보조 벨트만으로 고정 시키지 않을 것\""]', 0),
(7025, 'caution', 'default', '{"var":"crs_direction","eq":"both"}', '사용상 주의사항 (앞·뒤 겸용)', '["\"어린이가 허용된 몸무게를 초과하기 전에는 앞보기로 사용하지 말 것.\""]', 0),
(7025, 'caution', 'default', '{"var":"crs_direction","in":["rear","both"]}', '사용상 주의사항 (뒤보기)', '["\"에어백이 있는 앞좌석에 설치하지 말 것\""]', 0),
(7025, 'warning', 'default', '{"var":"crs_direction","in":["rear","both"]}', '경고문구 (뒤보기 장치)', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 3의 8.1.8~8.1.10 원문에서 문구 확인","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7025, 'warning', 'default', '{"var":"crs_fix","in":["isofix","isofix_belt"]}', '경고문구 (ISOFIX 고정 시스템)', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 3의 8.1.8~8.1.10 원문에서 문구 확인"]', 1),
(7025, 'manual', 'default', NULL, '사용설명서·부가 지시사항', '["위험방지 표시","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7025, 'display_method', 'default', NULL, '표시 방법', '["사용상 주의사항은 보호자가 쉽게 볼 수 있게","그룹·범주·구속형태의 가능한 조합은 부속서 3의 4 표 참조 (가이드 표는 추출이 깨져 검수 필요)"]', 0),
(7026, 'caution', 'default', NULL, '사용상 주의사항 (제품에 해당하는 것)', '["용도 이외는 사용하지 마십시오.","(원문 11줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7026, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 11의 7.2.1, 7.3 원문에서 문구 확인"]', 1),
(7026, 'warning', 'default', '{"var":"scented","eq":"yes"}', '경고문구 (향기 나는 제품)', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 11의 7.3 원문에서 문구 확인"]', 1),
(7027, 'caution', 'default', '{"var":"resin_type","eq":"guard"}', '사용상 주의사항 (침대가드)', '["침대 가드가 매트리스에 밀착되지 않아 틈이 생겼거나 머리판이나 발판으로부터 220 mm 이상의 거리가 확보되지 않을 경우, 절대로 사용하지 마십시오.","(원문 10줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7027, 'caution', 'default', '{"var":"resin_type","eq":"pacifier"}', '사용상 주의사항 (노리개젖꼭지)', '["손잡이나 고리 등 단단한 부품으로 인해 발생할 수 있는 위험성","(원문 2줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7027, 'caution', 'default', '{"var":"resin_type","eq":"holder"}', '사용상 주의사항 (노리개젖꼭지 걸이)', '["노리개젖꼭지 걸이의 길이를 늘이지 말 것","(원문 4줄 중 첫 줄만 수록 — 나머지는 원문 확인)"]', 1),
(7027, 'caution', 'default', '{"var":"resin_type","eq":"mat"}', '사용상 주의사항 (바닥매트)', '["부속서 2의 제4부 7.9 원문 확인 필요"]', 1),
(7027, 'warning', 'default', NULL, '경고문구', '["가이드에는 경고문구가 그림으로만 실려 있어요 — 부속서 2의 제1부 7.8 / 제2부 7.9 / 제3부 7.8 / 제4부 7.8 원문에서 문구 확인"]', 1),
(7027, 'manual', 'default', '{"var":"resin_type","eq":"guard"}', '사용설명서 (침대가드)', '["부속서 2의 제1부 7.10에 따름 — 원문 확인"]', 1),
(7028, 'caution', 'default', NULL, '사용상 주의사항 및 사용설명서', '["공통안전기준 5.7: 어린이가 이해하기 쉬운 문구로 제품 특성에 맞게 작성 — 원문 확인"]', 1),
(7028, 'display_method', 'default', NULL, '표시 방법', '["표면 또는 최소 포장단위에 붙이기·인쇄·새기기·꼬리표로 한글 표시, 개별 기준 표시사항이 있으면 그것을 따름"]', 0),
(7028, 'source_note', 'default', NULL, '원문 오류·주의', '["\"예시는 어린이용 킥보드에 한정\"과 한계하중 작성요령이 킥보드 페이지에서 복사됨"]', 1);

-- 품목 전용 질문 (scope=item). code = k01_textile_type 형식
INSERT INTO question_nodes (code, scope, category, item_id, group_id, trait_code, sort_order, question_text, help_text, input_type, save_as, show_if) VALUES
('k01_exclusion', 'item', NULL, 7001, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k01_textile_type', 'item', NULL, 7001, NULL, NULL, 21, '어떤 종류의 섬유제품인가요?', NULL, 'single_choice', 'textile_type', NULL),
('k01_small_parts', 'item', NULL, 7001, NULL, NULL, 22, '단추·장식처럼 떨어질 수 있는 작은 부품이 달려 있나요?', NULL, 'single_choice', 'small_parts', NULL),
('k01_soft_resin_shoes', 'item', NULL, 7001, NULL, NULL, 23, '신발이 말랑하거나 발포된 합성수지 재질인가요?', NULL, 'single_choice', 'soft_resin_shoes', '{"var":"textile_type","eq":"shoes"}'),
('k02_exclusion', 'item', NULL, 7002, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k02_bed_structure', 'item', NULL, 7002, NULL, NULL, 21, '침대 구조가 어떤가요?', NULL, 'single_choice', 'bed_structure', NULL),
('k03_exclusion', 'item', NULL, 7003, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k03_furniture_type', 'item', NULL, 7003, NULL, NULL, 21, '어떤 가구인가요?', NULL, 'single_choice', 'furniture_type', NULL),
('k03_furniture_age', 'item', NULL, 7003, NULL, NULL, 22, '어느 연령용 가구인가요?', NULL, 'single_choice', 'furniture_age', NULL),
('k03_small_parts', 'item', NULL, 7003, NULL, NULL, 23, '떼어질 수 있는 작은 부품이 있나요?', NULL, 'single_choice', 'small_parts', NULL),
('k05_exclusion', 'item', NULL, 7005, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k05_skate_use', 'item', NULL, 7005, NULL, NULL, 21, '어떤 용도인가요?', NULL, 'single_choice', 'skate_use', NULL),
('k06_exclusion', 'item', NULL, 7006, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k06_water_toy_type', 'item', NULL, 7006, NULL, NULL, 21, '어떤 제품인가요?', NULL, 'single_choice', 'water_toy_type', NULL),
('k07_exclusion', 'item', NULL, 7007, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k09_exclusion', 'item', NULL, 7009, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k10_exclusion', 'item', NULL, 7010, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k10_ski_type', 'item', NULL, 7010, NULL, NULL, 21, '어떤 스키용구인가요?', NULL, 'single_choice', 'ski_type', NULL),
('k11_exclusion', 'item', NULL, 7011, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k11_protector_type', 'item', NULL, 7011, NULL, NULL, 21, '어떤 제품인가요?', NULL, 'single_choice', 'protector_type', NULL),
('k11_helmet_visor', 'item', NULL, 7011, NULL, NULL, 22, '눈 보호구(투시부)가 달린 안전모인가요?', NULL, 'single_choice', 'helmet_visor', '{"var":"protector_type","eq":"helmet"}'),
('k12_exclusion', 'item', NULL, 7012, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k12_eyewear_type', 'item', NULL, 7012, NULL, NULL, 21, '어떤 제품인가요?', NULL, 'single_choice', 'eyewear_type', NULL),
('k12_visible_transmittance', 'item', NULL, 7012, NULL, NULL, 22, '가시광선 투과율(τV)은 몇 %인가요?', NULL, 'number', 'visible_transmittance', '{"var":"eyewear_type","eq":"sunglasses"}'),
('k12_uv_separate', 'item', NULL, 7012, NULL, NULL, 23, 'UV-A와 UV-B 차단율을 각각 알고 있나요?', NULL, 'single_choice', 'uv_separate', '{"var":"eyewear_type","eq":"sunglasses"}'),
('k13_exclusion', 'item', NULL, 7013, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k13_stick_type', 'item', NULL, 7013, NULL, NULL, 21, '몸이나 옷에 붙이는 타입인가요?', NULL, 'single_choice', 'stick_type', NULL),
('k14_exclusion', 'item', NULL, 7014, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k15_exclusion', 'item', NULL, 7015, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k15_bike_saddle_mm', 'item', NULL, 7015, NULL, NULL, 21, '안장을 가장 높게 올렸을 때 높이는 몇 mm인가요?', '바닥에서 안장 윗면까지의 최대 높이예요', 'number', 'bike_saddle_mm', NULL),
('k15_training_wheels', 'item', NULL, 7015, NULL, NULL, 22, '보조바퀴가 있나요?', NULL, 'single_choice', 'training_wheels', NULL),
('k16_exclusion', 'item', NULL, 7016, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k16_jewelry_material', 'item', NULL, 7016, NULL, NULL, 21, '주된 재질은 무엇인가요?', NULL, 'single_choice', 'jewelry_material', NULL),
('k17_exclusion', 'item', NULL, 7017, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k17_kick_handbrake', 'item', NULL, 7017, NULL, NULL, 21, '손으로 잡는 핸드브레이크가 있나요?', NULL, 'single_choice', 'kick_handbrake', NULL),
('k17_kick_powered', 'item', NULL, 7017, NULL, NULL, 22, '전동(모터)으로 가는 킥보드인가요?', NULL, 'single_choice', 'kick_powered', NULL),
('k18_exclusion', 'item', NULL, 7018, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k18_toy_age', 'item', NULL, 7018, NULL, NULL, 21, '몇 세 이상이 쓰는 완구인가요?', NULL, 'single_choice', 'toy_age', NULL),
('k18_toy_features', 'item', NULL, 7018, NULL, NULL, 22, '해당하는 특징을 모두 골라 주세요', '여러 개 골라도 돼요. 고른 특징마다 정해진 안전표시가 붙어요', 'multi_choice', 'toy_features', NULL),
('k18_toy_size_limit', 'item', NULL, 7018, NULL, NULL, 23, '옷처럼 입거나 타는 완구라 크기·체중 제한이 있나요?', NULL, 'single_choice', 'has_weight_limit', NULL),
('k18_toy_pack_with', 'item', NULL, 7018, NULL, NULL, 24, '식품이나 화장품과 함께 포장하나요?', NULL, 'single_choice', 'toy_pack_with', NULL),
('k19_exclusion', 'item', NULL, 7019, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k19_stroller_type', 'item', NULL, 7019, NULL, NULL, 21, '어떤 유모차인가요?', NULL, 'single_choice', 'stroller_type', NULL),
('k19_stroller_acc', 'item', NULL, 7019, NULL, NULL, 22, '함께 파는 부속품이 있나요?', '여러 개 골라도 돼요. 부속품은 그 품목 기준으로 따로 판정해요', 'multi_choice', 'stroller_accessories', NULL),
('k20_exclusion', 'item', NULL, 7020, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k20_parent_handle', 'item', NULL, 7020, NULL, NULL, 21, '보호자용 손잡이 봉과 발판이 있나요?', NULL, 'single_choice', 'parent_handle', NULL),
('k21_exclusion', 'item', NULL, 7021, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k21_textile_type', 'item', NULL, 7021, NULL, NULL, 21, '어떤 종류인가요?', NULL, 'single_choice', 'textile_type', NULL),
('k21_filling', 'item', NULL, 7021, NULL, NULL, 22, '솜·다운 같은 충전재가 들어 있나요?', NULL, 'single_choice', 'filling', NULL),
('k21_sleeping_bag_carpet', 'item', NULL, 7021, NULL, NULL, 23, '침낭이나 카페트인가요?', NULL, 'single_choice', 'sleeping_bag_carpet', '{"var":"textile_type","in":["bedding","other"]}'),
('k21_metal_accessory', 'item', NULL, 7021, NULL, NULL, 24, '금속 액세서리가 달려 있나요?', NULL, 'single_choice', 'metal_accessory', NULL),
('k21_small_parts', 'item', NULL, 7021, NULL, NULL, 25, '떨어질 수 있는 작은 부품이 있나요?', NULL, 'single_choice', 'small_parts', NULL),
('k21_soft_resin_shoes', 'item', NULL, 7021, NULL, NULL, 26, '말랑하거나 발포된 합성수지 신발인가요?', NULL, 'single_choice', 'soft_resin_shoes', '{"var":"textile_type","eq":"shoes"}'),
('k22_infant_chair_type', 'item', NULL, 7022, NULL, NULL, 20, '어떤 의자인가요?', NULL, 'single_choice', 'infant_chair_type', NULL),
('k23_exclusion', 'item', NULL, 7023, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k23_crib_type', 'item', NULL, 7023, NULL, NULL, 21, '어떤 제품인가요?', NULL, 'single_choice', 'crib_type', NULL),
('k23_crib_powered', 'item', NULL, 7023, NULL, NULL, 22, '전동으로 흔들리나요?', NULL, 'single_choice', 'crib_powered', '{"var":"crib_type","eq":"rocker"}'),
('k24_exclusion', 'item', NULL, 7024, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k24_carrier_frame', 'item', NULL, 7024, NULL, NULL, 21, '단단한 프레임이 있나요?', NULL, 'single_choice', 'carrier_frame', NULL),
('k24_carrier_type', 'item', NULL, 7024, NULL, NULL, 22, '어떤 방식인가요?', NULL, 'single_choice', 'carrier_type', '{"var":"carrier_frame","eq":"no"}'),
('k24_carrier_stand', 'item', NULL, 7024, NULL, NULL, 23, '스탠드가 붙어 있나요?', NULL, 'single_choice', 'carrier_stand', '{"var":"carrier_frame","eq":"yes"}'),
('k25_crs_type', 'item', NULL, 7025, NULL, NULL, 20, '어떤 종류인가요?', NULL, 'single_choice', 'crs_type', NULL),
('k25_crs_group', 'item', NULL, 7025, NULL, NULL, 21, '사용 가능한 체중 그룹은?', '여러 개 골라도 돼요', 'multi_choice', 'crs_group', NULL),
('k25_crs_category', 'item', NULL, 7025, NULL, NULL, 22, '사용범주는?', NULL, 'single_choice', 'crs_category', NULL),
('k25_crs_fix', 'item', NULL, 7025, NULL, NULL, 23, '고정(구속) 방법은?', NULL, 'single_choice', 'crs_fix', NULL),
('k25_crs_direction', 'item', NULL, 7025, NULL, NULL, 24, '어느 방향으로 장착하나요?', NULL, 'single_choice', 'crs_direction', NULL),
('k25_crs_aux_belt', 'item', NULL, 7025, NULL, NULL, 25, '보조벨트가 있나요?', NULL, 'single_choice', 'crs_aux_belt', NULL),
('k26_exclusion', 'item', NULL, 7026, NULL, NULL, 20, '아래 중 해당하는 게 있나요?', '해당하면 이 품목 기준이 아니거나 다른 품목으로 판정해요', 'single_choice', 'kids_exclusion', NULL),
('k26_school_type', 'item', NULL, 7026, NULL, NULL, 21, '어떤 학용품인가요?', NULL, 'single_choice', 'school_type', NULL),
('k26_sharpener_power', 'item', NULL, 7026, NULL, NULL, 22, '연필깎이는 어떻게 작동하나요?', NULL, 'single_choice', 'sharpener_power', '{"var":"school_type","eq":"sharpener"}'),
('k26_scented', 'item', NULL, 7026, NULL, NULL, 23, '향기가 나는 제품인가요?', NULL, 'single_choice', 'scented', NULL),
('k27_resin_type', 'item', NULL, 7027, NULL, NULL, 20, '어떤 제품인가요?', NULL, 'single_choice', 'resin_type', NULL),
('k27_mat_type', 'item', NULL, 7027, NULL, NULL, 21, '어떤 바닥매트인가요?', NULL, 'single_choice', 'mat_type', '{"var":"resin_type","eq":"mat"}'),
('k27_puzzle_play', 'item', NULL, 7027, NULL, NULL, 22, '문자·숫자·도형을 끼웠다 뺐다 하는 놀이 기능이 있나요?', NULL, 'single_choice', 'puzzle_play', '{"var":"mat_type","eq":"puzzle"}'),
('k28_other_confirm', 'item', NULL, 7028, NULL, NULL, 20, '위의 개별 품목(완구, 섬유, 가구 등) 중 어디에도 해당하지 않는 게 확실한가요?', NULL, 'single_choice', 'kids_other_confirm', NULL),
('k28_size_limit', 'item', NULL, 7028, NULL, NULL, 21, '크기·체중 제한이 있나요?', NULL, 'single_choice', 'has_weight_limit', NULL);

INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '맞춤복이에요', 'x1', '{}', 'out_of_scope', NULL, '맞춤복은 아동용 섬유제품 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k01_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '놀이용 가장복(코스튬)이에요', 'x2', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k01_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '가죽·인조가죽·모피로 된 신발이에요', 'x3', '{}', 'switch_item', 'K-04', NULL FROM question_nodes WHERE code = 'k01_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '외의류 (재킷, 코트, 점퍼 등)', 'outer', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '중의류 (티셔츠, 바지, 수영복 등)', 'middle', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '내의류 (속옷, 잠옷 등)', 'inner', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '침구류 (이불, 베개, 매트 등)', 'bedding', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '신발류 (천·합성수지 신발)', 'shoes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '양말·장갑·모자류', 'accessory', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 7, '가방류', 'bag', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 8, '방한용·패션용·스포츠용 마스크', 'mask', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 9, '기타', 'other', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_soft_resin_shoes';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k01_soft_resin_shoes';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '포장에 "성인을 위한 것" 또는 "어린이용이 아님"이 표시된 2단 침대예요', 'x1', '{}', 'out_of_scope', NULL, '성인용으로 표시된 2단 침대는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k02_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k02_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '2단 침대', 'bunk', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k02_bed_structure';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '1층짜리지만 바닥판 높이가 800 mm 이상 (로프트형)', 'loft', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k02_bed_structure';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '1층이고 바닥판 높이 800 mm 미만', 'low', '{}', 'escalate', NULL, '바닥판 800 mm 미만 1층 침대는 이단침대 적용범위 밖이에요 — 어떤 기준인지 확인이 필요해요.' FROM question_nodes WHERE code = 'k02_bed_structure';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '가구 모양의 장난감(가구완구)이에요', 'x1', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '유아용 식사 의자예요', 'x2', '{}', 'switch_item', 'K-22', NULL FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '2단 침대예요', 'x3', '{}', 'switch_item', 'K-02', NULL FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '요람·유아용 침대·놀이 울타리예요', 'x4', '{}', 'switch_item', 'K-23', NULL FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '실험실용 기자재예요', 'x5', '{}', 'out_of_scope', NULL, '실험실용 기자재는 어린이용 가구 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '책상·탁자', 'desk', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '의자', 'chair', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '수납가구 (옷장, 서랍장, 책장 등)', 'storage', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '침대', 'bed', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '소파', 'sofa', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '조립식 가구 (DIY)', 'diy', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 7, '기타 (검색대, 강연대 등)', 'other', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '영·유아용 (3세 미만)', 'infant', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '어린이용 (3세 이상 ~ 8세 미만)', 'child', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '학생용 (8세 이상)', 'student', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_furniture_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k03_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '바퀴에 베어링이 없어요', 'x1', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k05_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '구두 장착부 길이가 180 mm 미만이에요', 'x2', '{}', 'escalate', NULL, '구두 장착부 180 mm 미만은 적용범위 밖일 수 있어요 — 전문가 확인이 필요해요.' FROM question_nodes WHERE code = 'k05_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k05_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '레저용', 'leisure', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k05_skate_use';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '경기용', 'race', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k05_skate_use';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '가정용 어린이 풀(수영장)이에요', 'x1', '{}', 'out_of_scope', NULL, '가정용 어린이 풀은 물놀이기구 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k06_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k06_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '공기를 넣어 노는 물놀이기구 (튜브, 에어매트, 비치볼 등)', 'inflatable', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k06_water_toy_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '몸에 착용하는 수영보조용품 (암링, 수영조끼 등)', 'aid_wear', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k06_water_toy_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '손으로 잡거나 끼우는 수영보조용품 (킥판, 풀부이 등)', 'aid_hold', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k06_water_toy_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '잠수(스킨·스쿠버 다이빙)용이에요', 'x1', '{}', 'out_of_scope', NULL, '잠수용은 물안경 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k07_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '도수가 있는 물안경이에요', 'x2', '{}', 'out_of_scope', NULL, '도수 물안경은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k07_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k07_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '모터(동력)가 달려 있어요', 'x1', '{}', 'out_of_scope', NULL, '동력이 있는 스케이트보드는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k09_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '체중 20 kg 이하 어린이용(장난감)이에요', 'x2', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k09_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k09_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '경기용이나 특수 용도예요', 'x1', '{}', 'out_of_scope', NULL, '경기용·특수 용도 스키용구는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k10_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k10_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '스키 (알파인)', 'ski', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k10_ski_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '스키화', 'boot', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k10_ski_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '스키바인딩', 'binding', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k10_ski_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '롤러 하키용이에요', 'x1', '{}', 'out_of_scope', NULL, '롤러 하키용은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k11_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k11_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '보호장구 (무릎·팔꿈치·손목·손바닥 보호대)', 'pad', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k11_protector_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '안전모', 'helmet', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k11_protector_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k11_helmet_visor';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k11_helmet_visor';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '산업용 등 특수 용도 안경테예요', 'x1', '{}', 'out_of_scope', NULL, '특수 용도 안경테는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k12_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '스키 고글 같은 스포츠용 보안경이에요', 'x2', '{}', 'out_of_scope', NULL, '스포츠용 보안경은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k12_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '의료용 처방, 태양 직접 관찰용, 광색·편광 특수 필터예요', 'x3', '{}', 'out_of_scope', NULL, '의료용·특수 필터 제품은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k12_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '자외선 차단 기능이 없는 장난감 선글라스예요', 'x4', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k12_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k12_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '안경테', 'frame', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k12_eyewear_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '선글라스', 'sunglasses', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k12_eyewear_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네, 각각 알아요', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k12_uv_separate';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요, 자외선 차단율 하나만 있어요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k12_uv_separate';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '전기(충전·USB)로 데워지는 제품이에요', 'x1', '{}', 'out_of_scope', NULL, '전기로 데워지는 제품은 온열팩 기준 대상이 아니에요(전기용품 확인).' FROM question_nodes WHERE code = 'k13_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k13_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k13_stick_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k13_stick_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '일회용 비닐우산이에요', 'x1', '{}', 'out_of_scope', NULL, '일회용 비닐우산은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k14_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '놀이용 완구 우산이에요', 'x2', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k14_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k14_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, 'BMX 같은 묘기용 특수 자전거예요', 'x1', '{}', 'out_of_scope', NULL, '묘기용 특수 자전거는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k15_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k15_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k15_training_wheels';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k15_training_wheels';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '금(함량 58.5% 이상)이나 은 제품이에요', 'x1', '{}', 'out_of_scope', NULL, '금·은 제품은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '인형이 착용하는 장신구 등 놀이용이에요', 'x2', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '알람·멜로디·반짝임 같은 부가기능이 있어요', 'x3', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '가방·벨트 등에 달린 액세서리예요', 'x4', '{}', 'escalate', NULL, '가방·벨트에 달린 액세서리는 적용 여부 확인이 필요해요(전문가 확인).' FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '일회용 미아방지 팔찌예요', 'x5', '{}', 'out_of_scope', NULL, '일회용 미아방지 팔찌는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '플라스틱', 'plastic', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_jewelry_material';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '금속 (도금 포함)', 'metal', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_jewelry_material';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '섬유', 'textile', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_jewelry_material';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '나무', 'wood', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_jewelry_material';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '가죽', 'leather', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k16_jewelry_material';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '바퀴에 베어링이 없어요', 'x1', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k17_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '연료로 움직여요', 'x2', '{}', 'out_of_scope', NULL, '연료로 움직이는 킥보드는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k17_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '좌석이 있어요', 'x3', '{}', 'out_of_scope', NULL, '좌석이 있으면 킥보드 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k17_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k17_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k17_kick_handbrake';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k17_kick_handbrake';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k17_kick_powered';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k17_kick_powered';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '어린이 비비탄총이에요', 'x1', '{}', 'escalate', NULL, '어린이용 비비탄총은 어린이제품 안전인증 품목이에요(가이드 자료 미수집) — 전문가 확인이 필요해요.' FROM question_nodes WHERE code = 'k18_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '3세 미만도 사용', 'under3', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '3세 이상', '3plus', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '8세 이상', '8plus', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '기타 연령', 'other', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_age';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '작은 부품이 있거나 작은 완구예요', 'small_parts', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '풍선이에요', 'balloon', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '작은 공이나 구슬이 있어요', 'small_ball', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '물놀이 완구예요', 'water', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '유아 침대용 완구·모빌·크립짐이에요', 'crib_mobile', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '음식과 닿게 쓰는 완구예요', 'food_contact', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 7, '성인이 조립해야 해요', 'adult_assembly', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 8, '모조 보호장구 (장난감 헬멧·선글라스 등)예요', 'mock_protective', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 9, '기능상 날카로운 가장자리·끝이 있어요', 'sharp_function', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 10, '기능 완구예요 (어른 제품의 기능을 가진 축소형)', 'functional', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 11, '완구 롤러스케이트·스케이트보드예요', 'toy_skate', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 12, '발사체 완구예요', 'projectile', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 13, '완구 연이에요', 'kite', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 14, '완구 자전거예요', 'toy_bike', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 15, '격발 장치(딱총 등)가 있어요', 'cap', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 16, '순간적으로 큰 소리를 내요', 'loud', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 17, '유아가 입에 넣도록 만든 완구예요', 'mouth', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 18, '긴 털(단섬유)이 있어요', 'long_fiber', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 19, '끄는 완구예요 (타는 용도 아님)', 'pull_toy', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 20, '타고 노는 완구예요', 'ride_on', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 21, '전동 승용 완구예요', 'power_ride', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 22, '전원선(전등선)을 써요', 'cord_power', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 23, '건전지를 써요', 'battery', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 24, '열을 내요', 'heat', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 25, '접착제·용제가 들어 있어요', 'adhesive', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 26, '액체가 들어 있어요', 'liquid', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 27, '식품이 함께 들어 있어요', 'with_food', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 28, '완구 상자(뚜껑 있는 수납함)예요', 'toy_box', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 29, '액체를 채운 치아 발육기예요', 'liquid_teether', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 30, '완구 스쿠터 (최대 20 kg)예요', 'scooter20', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 31, '완구 스쿠터 (최대 50 kg)예요', 'scooter50', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 32, '자석·전기 실험 세트예요', 'magnet_kit', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 33, '장난감 총이에요', 'toy_gun', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 34, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_features';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_size_limit';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_size_limit';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '식품과 함께', 'food', '{}', 'escalate', NULL, '식품과 함께 포장하면 식품 쪽 표시 기준도 따로 확인이 필요해요.' FROM question_nodes WHERE code = 'k18_toy_pack_with';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '화장품과 함께', 'cosmetic', '{}', 'escalate', NULL, '화장품과 함께 포장하면 화장품 쪽 표시 기준도 따로 확인이 필요해요.' FROM question_nodes WHERE code = 'k18_toy_pack_with';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k18_toy_pack_with';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '완구(인형 유모차)예요', 'x1', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k19_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '쇼핑 운반기구예요', 'x2', '{}', 'out_of_scope', NULL, '쇼핑 운반기구는 유모차 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k19_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '모터로 움직이는 바퀴 달린 캐리어예요', 'x3', '{}', 'out_of_scope', NULL, '모터로 움직이는 캐리어는 유모차 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k19_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '특별한 도움이 필요한 어린이용 이동수단이에요', 'x4', '{}', 'out_of_scope', NULL, '특수 이동수단은 유모차 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k19_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, 'A형 (신생아부터, 등받이 150° 이상 조절)', 'a', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, 'B형 (6개월부터, 등받이 150° 미만)', 'b', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '상자형 해먹형 (사방이 막혀 누이는 형태)', 'box', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '카시트 부착형', 'car_seat', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '컵홀더·식판 (합성수지)', 'cupholder', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_acc';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '양산·우산', 'umbrella', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_acc';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '딸랑이·삑삑이', 'rattle', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_acc';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '풋머프 등 섬유제품', 'footmuff', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_acc';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k19_stroller_acc';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '손의 힘으로 작동하는 삼륜차예요', 'x1', '{}', 'out_of_scope', NULL, '손의 힘으로 작동하는 삼륜차는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k20_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k20_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k20_parent_handle';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k20_parent_handle';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '맞춤복이에요', 'x1', '{}', 'out_of_scope', NULL, '맞춤복은 유아용 섬유제품 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k21_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '놀이용 가장복(코스튬)이에요', 'x2', '{}', 'switch_item', 'K-18', NULL FROM question_nodes WHERE code = 'k21_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '가죽·인조가죽·모피로 된 신발이에요', 'x3', '{}', 'switch_item', 'K-04', NULL FROM question_nodes WHERE code = 'k21_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '합성수지 재질 바닥매트예요', 'x4', '{}', 'switch_item', 'K-27', NULL FROM question_nodes WHERE code = 'k21_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '외의류 (재킷, 코트, 점퍼 등)', 'outer', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '중의류 (티셔츠, 바지, 수영복 등)', 'middle', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '내의류 (속옷, 잠옷 등)', 'inner', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '침구류 (이불, 베개, 매트 등)', 'bedding', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '신발류 (천·합성수지 신발)', 'shoes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '양말·장갑·모자류', 'accessory', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 7, '가방류', 'bag', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 8, '방한용·패션용·스포츠용 마스크', 'mask', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 9, '신생아용품', 'newborn', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 10, '기타', 'other', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_textile_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '다운(솜털·깃털)', 'down', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_filling';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '그 밖의 충전재', 'other', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_filling';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_filling';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_sleeping_bag_carpet';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_sleeping_bag_carpet';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_metal_accessory';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_metal_accessory';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_small_parts';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_soft_resin_shoes';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k21_soft_resin_shoes';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '높은 의자 (하이체어)', 'high', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k22_infant_chair_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '부스터 의자 (성인 의자 위에 장착)', 'booster', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k22_infant_chair_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '테이블부착식 의자', 'table', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k22_infant_chair_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '병원·보육원용 유아 침대예요', 'x1', '{}', 'out_of_scope', NULL, '병원·보육원용은 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k23_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '유아 이동용 침대예요', 'x2', '{}', 'out_of_scope', NULL, '이동용 침대는 이 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k23_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '기울어진 요람·간이침대 (시소식·그네식·전동식, 유아용 그네)', 'rocker', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '가정용 유아용 침대·요람', 'crib', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '유아용 침대·접이침대 (바닥 내부 길이 900 mm 초과)', 'large', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '가정용 놀이 울타리 (15 kg 이하)', 'playpen', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_powered';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k23_crib_powered';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '허리에만 차고 손으로 아기를 받치는 제품이에요', 'x1', '{}', 'out_of_scope', NULL, '허리에만 차는 제품은 유아용 캐리어 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k24_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '없어요 (천으로 된 아기띠·슬링 등)', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_frame';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '있어요', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_frame';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '후면식 (업는 형식)', 'back', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '전면식 (앞으로 안는 형식)', 'front', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '혼합식', 'mixed', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_stand';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k24_carrier_stand';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '휴대용 유아침대', 'cot', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '유아용 좌석', 'infant_seat', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '부스터 좌석 (15 kg 이상)', 'booster', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '하네스·조끼형 (15 kg 이상)', 'harness', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '0 그룹 (10 kg 미만)', 'g0', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_group';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '0+ 그룹 (13 kg 미만)', 'g0p', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_group';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, 'Ⅰ 그룹 (9~18 kg)', 'g1', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_group';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, 'Ⅱ 그룹 (15~25 kg)', 'g2', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_group';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, 'Ⅲ 그룹 (22~36 kg)', 'g3', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_group';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '범용', 'universal', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_category';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '준범용', 'semi', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_category';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '제한적 사용', 'restricted', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_category';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '특정 자동차용', 'specific', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_category';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '차량 안전벨트', 'belt', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_fix';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, 'ISOFIX 전용', 'isofix', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_fix';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, 'ISOFIX + 안전벨트', 'isofix_belt', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_fix';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, 'Latch형 + 안전벨트 겸용', 'latch', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_fix';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '앞보기', 'front', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_direction';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '뒤보기', 'rear', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_direction';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '옆보기', 'side', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_direction';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '앞보기·뒤보기 겸용', 'both', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_direction';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_aux_belt';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k25_crs_aux_belt';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '사무용·전문가용 표시가 된 제품이에요', 'x1', '{}', 'out_of_scope', NULL, '사무용·전문가용 표시 제품은 학용품 기준 대상이 아니에요.' FROM question_nodes WHERE code = 'k26_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '반짝이 풀이에요', 'x2', '{}', 'escalate', NULL, '반짝이 풀은 적용 기준 확인이 필요해요(전문가 확인).' FROM question_nodes WHERE code = 'k26_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '해당 없어요', 'none', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_exclusion';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '크레용·크레파스', 'crayon', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '연필·색연필·연필심', 'pencil', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '샤프연필·샤프심', 'mech_pencil', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '지우개', 'eraser', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 5, '파스텔', 'pastel', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 6, '그림물감 (수채·아크릴)', 'paint', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 7, '분필', 'chalk', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 8, '마킹펜 (보드마카·형광펜·사인펜)', 'marker', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 9, '연필깎이', 'sharpener', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 10, '필통', 'pencil_case', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 11, '색종이', 'color_paper', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 12, '공책', 'notebook', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 13, '스케치북', 'sketchbook', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 14, '문구용 풀', 'glue', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 15, '악기류', 'instrument', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_school_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '손으로 돌려요', 'manual', '{"power_type":"none"}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_sharpener_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '전동 (충전·건전지)', 'battery', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_sharpener_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '전동 (콘센트)', 'plug', '{"power_type":"ac_plug"}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_sharpener_power';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_scented';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k26_scented';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '어린이용 침대가드', 'guard', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_resin_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '유아용 노리개젖꼭지', 'pacifier', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_resin_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '노리개젖꼭지 걸이 (클립·줄)', 'holder', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_resin_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '바닥매트', 'mat', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_resin_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '돗자리형 (말아서 보관)', 'roll', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_mat_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '폴더형 (접이식)', 'fold', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_mat_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 3, '퍼즐형 (여러 장 연결)', 'puzzle', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_mat_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 4, '야외용이거나 충격흡수층이 없어요', 'outdoor', '{}', 'escalate', NULL, '야외용이거나 충격흡수층이 없는 매트는 적용 여부 확인이 필요해요(전문가 확인).' FROM question_nodes WHERE code = 'k27_mat_type';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_puzzle_play';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k27_puzzle_play';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네, 해당 없어요', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k28_other_confirm';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '잘 모르겠어요', 'unknown', '{}', 'escalate', NULL, '개별 어린이제품 품목에 해당하는지 전문가 확인이 필요해요.' FROM question_nodes WHERE code = 'k28_other_confirm';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 1, '네', 'yes', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k28_size_limit';
INSERT INTO question_options (node_id, sort_order, label, value, sets, action, action_target, action_message) SELECT id, 2, '아니요', 'no', '{}', 'next', NULL, NULL FROM question_nodes WHERE code = 'k28_size_limit';

INSERT INTO item_scope_rules (item_id, rule_code, description, question_code, fail_if, on_fail, target_cert, target_item, verified) VALUES
(7015, 'saddle_toy', '안장 최대 높이 435 mm 이하는 완구 기준 → 완구(K-18)로 전환', 'k15_bike_saddle_mm', '{"var":"bike_saddle_mm","lte":435}', 'switch_item', NULL, 'K-18', 0),
(7015, 'saddle_over', '안장 최대 높이 635 mm 이상은 어린이용 자전거 범위 밖 — 전문가 확인', 'k15_bike_saddle_mm', '{"var":"bike_saddle_mm","gte":635}', 'escalate', NULL, NULL, 0),
(7025, 'crs_booster_group', '부스터 좌석·하네스형은 15 kg 이상 어린이용이라 0·0+ 그룹과 맞지 않아요 — 전문가 확인', 'k25_crs_group', '{"all":[{"var":"crs_type","in":["booster","harness"]},{"any":[{"var":"crs_group","has":"g0"},{"var":"crs_group","has":"g0p"}]}]}', 'escalate', NULL, NULL, 0);

INSERT INTO item_relations (item_id, related_item_id, relation, trigger_if, basis, verified) VALUES
(7019, (SELECT id FROM items WHERE code = 'K-25'), 'parallel', '{"var":"stroller_type","eq":"car_seat"}', '카시트 부착형이면 자동차용 어린이보호장치 기준 병행', 0),
(7019, (SELECT id FROM items WHERE code = 'K-27'), 'component', '{"var":"stroller_accessories","has":"cupholder"}', '함께 파는 컵홀더·식판은 합성수지제 어린이용품 기준', 0),
(7019, (SELECT id FROM items WHERE code = 'K-14'), 'component', '{"var":"stroller_accessories","has":"umbrella"}', '함께 파는 양산·우산은 어린이용 우산 및 양산 기준', 0),
(7019, (SELECT id FROM items WHERE code = 'K-18'), 'component', '{"var":"stroller_accessories","has":"rattle"}', '함께 파는 딸랑이는 완구 기준', 0),
(7019, (SELECT id FROM items WHERE code = 'K-21'), 'component', '{"var":"stroller_accessories","has":"footmuff"}', '함께 파는 풋머프는 유아용 섬유제품 기준', 0),
(7027, (SELECT id FROM items WHERE code = 'K-18'), 'parallel', '{"var":"puzzle_play","eq":"yes"}', '놀이 기능이 있는 퍼즐 매트는 완구 기준도 병행', 0);

INSERT INTO item_traits (item_id, trait_code, applies_if, question_override, example_hint, source) VALUES
(7017, 'may_use_power', '{"var":"kick_powered","eq":"yes"}', NULL, '전동 킥보드', 'manual'),
(7023, 'may_use_power', '{"var":"crib_type","eq":"rocker"}', NULL, '전동 바운서', 'manual'),
(7026, 'may_use_power', '{"var":"school_type","eq":"sharpener"}', NULL, '전동 연필깎이', 'manual');

-- 연령 등급 분기: 사용연령 질문(t_age) 답으로 어린이제품/생활용품 중 하나를 고른다
--   어린이 쪽: 품목 적용범위 연령 / 생활용품 쪽: 청소년·어른(over_13y) 또는 나이 상관없이(all)
INSERT INTO item_groups (id, code, name, kind, selector_node) VALUES
(701, 'G-K01', '아동용 섬유제품·유아용 섬유제품 (연령 등급 분기)', 'age_class', 't_age'),
(702, 'G-K02', '어린이용 가구 (연령 등급 분기)', 'age_class', 't_age'),
(703, 'G-K03', '어린이용 가죽제품 (연령 등급 분기)', 'age_class', 't_age'),
(704, 'G-K04', '어린이용 롤러스케이트 (연령 등급 분기)', 'age_class', 't_age'),
(705, 'G-K05', '어린이용 물놀이기구 (연령 등급 분기)', 'age_class', 't_age'),
(706, 'G-K06', '어린이용 물안경 (연령 등급 분기)', 'age_class', 't_age'),
(707, 'G-K07', '어린이용 바퀴 달린 운동화 (연령 등급 분기)', 'age_class', 't_age'),
(708, 'G-K08', '어린이용 스케이트보드 (연령 등급 분기)', 'age_class', 't_age'),
(709, 'G-K09', '어린이용 스키용구 (연령 등급 분기)', 'age_class', 't_age'),
(710, 'G-K10', '어린이용 스포츠 보호용품 (연령 등급 분기)', 'age_class', 't_age'),
(711, 'G-K11', '어린이용 안경테 및 선글라스 (연령 등급 분기)', 'age_class', 't_age'),
(712, 'G-K12', '어린이용 온열팩 (연령 등급 분기)', 'age_class', 't_age'),
(713, 'G-K13', '어린이용 우산 및 양산 (연령 등급 분기)', 'age_class', 't_age'),
(714, 'G-K14', '어린이용 자전거 (연령 등급 분기)', 'age_class', 't_age'),
(715, 'G-K15', '어린이용 장신구 (연령 등급 분기)', 'age_class', 't_age'),
(716, 'G-K16', '어린이용 킥보드 (연령 등급 분기)', 'age_class', 't_age');

INSERT INTO item_group_members (group_id, item_id, select_if, card_summary) VALUES
(701, 7001, '{"var":"age_group","in":["36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(701, 7021, '{"var":"age_group","in":["under_36m"]}', '어린이제품 · 안전확인'),
(701, (SELECT id FROM items WHERE code = 'L-0084'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(702, 7003, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(702, (SELECT id FROM items WHERE code = 'L-0088'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(702, (SELECT id FROM items WHERE code = 'L-0065'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(703, 7004, '{"var":"age_group","in":["36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(703, (SELECT id FROM items WHERE code = 'L-0086'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(704, 7005, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(704, (SELECT id FROM items WHERE code = 'L-0066'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(705, 7006, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 안전인증'),
(705, (SELECT id FROM items WHERE code = 'L-0005'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(705, (SELECT id FROM items WHERE code = 'L-0006'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(705, (SELECT id FROM items WHERE code = 'L-0007'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(705, (SELECT id FROM items WHERE code = 'L-0008'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(706, 7007, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(706, (SELECT id FROM items WHERE code = 'L-0097'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(707, 7008, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(707, (SELECT id FROM items WHERE code = 'L-0067'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(708, 7009, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 안전확인'),
(708, (SELECT id FROM items WHERE code = 'L-0025'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(709, 7010, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(709, (SELECT id FROM items WHERE code = 'L-0029'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(710, 7011, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 안전확인'),
(710, (SELECT id FROM items WHERE code = 'L-0023'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(710, (SELECT id FROM items WHERE code = 'L-0042'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(711, 7012, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(711, (SELECT id FROM items WHERE code = 'L-0089'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(711, (SELECT id FROM items WHERE code = 'L-0090'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(712, 7013, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 안전확인'),
(712, (SELECT id FROM items WHERE code = 'L-0048'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(713, 7014, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(713, (SELECT id FROM items WHERE code = 'L-0102'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(714, 7015, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 안전확인'),
(714, (SELECT id FROM items WHERE code = 'L-0030'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(714, (SELECT id FROM items WHERE code = 'L-0031'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(715, 7016, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(715, (SELECT id FROM items WHERE code = 'L-0104'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)'),
(716, 7017, '{"var":"age_group","in":["under_36m","36m_to_13y"]}', '어린이제품 · 공급자적합성확인'),
(716, (SELECT id FROM items WHERE code = 'L-0081'), '{"var":"age_group","in":["over_13y","all"]}', '생활용품 (만 14세 이상·연령 무관)');
