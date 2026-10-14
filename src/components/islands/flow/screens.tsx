import { useMemo, useRef, useState, type DragEvent, type ReactNode } from 'react';
import {
  CATEGORY_LABEL,
  CERT_LABEL,
  FLOW_STEPS,
  PROCESS_TYPE_INFO,
  type Draft,
  type DraftRow,
  type ItemRole,
  type Screen,
} from '../../../lib/flow-types';

export type Answer = (key: string, value: string, extra?: { facts?: Record<string, string> }) => void;

type S<T extends Screen['type']> = Extract<Screen, { type: T }>;

const ROLE_LABEL: Record<ItemRole, string> = { primary: '주 품목', parallel: '병행 기준', component: '구성품' };

// ------------------------------------------------------------------ 공통

export function StepLabel({ index }: { index: number }) {
  return (
    <p className="flow-step">
      {index + 1}/{FLOW_STEPS.length} · {FLOW_STEPS[index]}
    </p>
  );
}

export function CtaBar({ children }: { children: ReactNode }) {
  return (
    <div className="cta-bar">
      <div className="cta-inner">{children}</div>
    </div>
  );
}

export function Cta({ label, disabled, busy, onClick }: { label: string; disabled?: boolean; busy?: boolean; onClick: () => void }) {
  return (
    <button type="button" className="btn-primary cta" disabled={disabled || busy} onClick={onClick}>
      {busy ? <span className="spinner" aria-label="처리 중" /> : label}
    </button>
  );
}

function Check() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" aria-hidden="true">
      <path d="m5 12 5 5 9-10" />
    </svg>
  );
}

// ------------------------------------------------------------------ 1. 파일 업로드

const ACCEPT = '.pdf,.png,.jpg,.jpeg,.webp,.heic,.heif,.txt';
const MAX_FILES = 8;
const fmtSize = (b: number) => (b < 1024 * 1024 ? `${Math.max(1, Math.round(b / 1024))} KB` : `${(b / 1024 / 1024).toFixed(1)} MB`);

export function UploadScreen({ busy, onStart }: { busy: boolean; onStart: (name: string, files: File[]) => void }) {
  const [name, setName] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [drag, setDrag] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  const add = (list: FileList | null) => {
    if (!list) return;
    setFiles((prev) => {
      const names = new Set(prev.map((f) => f.name));
      return [...prev, ...Array.from(list).filter((f) => !names.has(f.name))].slice(0, MAX_FILES);
    });
  };
  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDrag(false);
    add(e.dataTransfer.files);
  };

  return (
    <>
      <StepLabel index={0} />
      <h1 className="flow-title">{'어떤 제품의 표시사항을\n만들까요?'}</h1>
      <p className="flow-sub">이름, 사진, 설명서, 인증서 — 있는 대로 다 주시면 필요한 것만 골라 쓸게요.</p>

      <div className="f-field">
        <label className="f-label" htmlFor="pname">
          제품 이름
        </label>
        <input id="pname" className="f-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="예: 탁상용 선풍기" maxLength={100} autoComplete="off" />
      </div>

      <div className="f-field">
        <span className="f-label">제품 자료</span>
        <div
          className={`drop ${drag ? 'drag' : ''}`}
          role="button"
          tabIndex={0}
          onClick={() => input.current?.click()}
          onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && input.current?.click()}
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={onDrop}
        >
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true">
            <path d="M12 16V4m0 0-4.5 4.5M12 4l4.5 4.5" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" strokeLinecap="round" />
          </svg>
          <strong>자료를 끌어다 놓거나 눌러서 고르세요</strong>
          <span>인증서·시험성적서·설명서·제품/라벨 사진</span>
          <input
            ref={input}
            type="file"
            accept={ACCEPT}
            multiple
            hidden
            onChange={(e) => {
              add(e.target.files);
              e.target.value = '';
            }}
          />
        </div>
        {files.length > 0 && (
          <ul className="files">
            {files.map((f) => (
              <li key={f.name}>
                <span className="ext">{f.name.split('.').pop()?.toUpperCase()}</span>
                <span className="name" title={f.name}>
                  {f.name}
                </span>
                <span className="size">{fmtSize(f.size)}</span>
                <button type="button" aria-label={`${f.name} 빼기`} onClick={() => setFiles((p) => p.filter((x) => x !== f))}>
                  ×
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="info-box">
        <strong>참고해 주세요</strong>
        <ul>
          <li>인증서가 있으면 가장 정확해요. 자료끼리 다르면 인증서 → 설명서 → 사진 순으로 믿어요.</li>
          <li>PDF, JPG, PNG, WEBP, HEIC, TXT · 파일당 10MB, 최대 {MAX_FILES}개</li>
          <li>HWP·DOCX는 PDF로 저장해서 올려 주세요.</li>
          <li>원본 파일은 저장하지 않고, 읽어낸 내용만 판정에 써요.</li>
        </ul>
      </div>

      <CtaBar>
        <Cta label="다음" busy={busy} disabled={!name.trim() && !files.length} onClick={() => onStart(name.trim(), files)} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 로딩

const READ_STEPS = ['자료의 글자를 읽고 있어요', '제품 정보를 찾고 있어요', '자료끼리 맞춰 보고 있어요'];

export function LoadingScreen({ phase }: { phase: number }) {
  return (
    <div className="loading" role="status" aria-live="polite">
      <div className="big-spin" />
      <h1 className="flow-title">{'자료를 읽고 있어요'}</h1>
      <p className="flow-sub" style={{ margin: 0 }}>
        자료 양에 따라 10~40초 정도 걸려요.
      </p>
      <ol>
        {READ_STEPS.map((s, i) => (
          <li key={s} className={i < phase ? 'done' : i === phase ? 'on' : ''}>
            {i < phase ? '✓ ' : i === phase ? '● ' : '○ '}
            {s}
          </li>
        ))}
      </ol>
    </div>
  );
}

// ------------------------------------------------------------------ 2. 문서 내용 추출 확인

const FACT_LABELS: Record<string, string> = {
  product_name: '제품명',
  generic_names: '일반 품목명',
  main_function: '주된 기능',
  model_name: '모델명',
  maker: '제조자',
  importer: '수입자',
  country: '제조국',
  address_phone: '주소·전화번호',
  as_contact: 'A/S 연락처',
  rating: '정격',
  voltage_type: '전원 종류 (AC/DC)',
  voltage_v: '전압(V)',
  power_w: '소비전력(W)',
  frequency_hz: '주파수(Hz)',
  cert_no: '인증·신고번호',
  battery: '배터리 (none/rechargeable/dry_cell)',
  has_wireless: '무선 기능 (yes/no)',
  food_contact: '음식 접촉 (yes/no)',
  min_age: '최소 사용연령(세)',
  mfg_date: '제조연월',
};

export function FactsScreen({ screen, busy, onAnswer }: { screen: S<'facts'>; busy: boolean; onAnswer: Answer }) {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(screen.facts.map((f) => [f.key, f.value])));
  const [extra, setExtra] = useState<string[]>([]);
  const shown = [...screen.facts.map((f) => f.key), ...extra];
  const addable = Object.keys(FACT_LABELS).filter((k) => !shown.includes(k));
  const info = new Map(screen.facts.map((f) => [f.key, f]));
  const empty = !screen.facts.length;

  return (
    <>
      <StepLabel index={1} />
      <h1 className="flow-title">{empty ? '자료에서 찾은 값이 없어요' : '자료에서 이렇게 찾았어요'}</h1>
      <p className="flow-sub">
        {empty
          ? '알고 있는 값만 적어 주시면 돼요. 판정에 필요한 건 다음 단계에서 하나씩 물어볼게요.'
          : '틀린 값은 고치고, 아닌 값은 지워 주세요. 여기서 확인된 값은 다시 묻지 않아요.'}
      </p>

      {screen.docs.length > 0 && (
        <div className="doc-chips">
          {screen.docs.map((d) => (
            <span key={d.name} className="doc-chip">
              <b>{d.name}</b> · {d.kind}
            </span>
          ))}
        </div>
      )}
      {screen.productName && (
        <div className="doc-chips">
          <span className="doc-chip">
            직접 입력한 이름 · <b>{screen.productName}</b>
          </span>
        </div>
      )}

      {screen.warnings.length > 0 && (
        <div className="warn-box">
          <ul>
            {screen.warnings.map((w) => (
              <li key={w}>{w}</li>
            ))}
          </ul>
        </div>
      )}

      {shown.map((key) => {
        const f = info.get(key);
        return (
          <div className="f-field" key={key}>
            <label className="f-label" htmlFor={`fact-${key}`}>
              {f?.label ?? FACT_LABELS[key] ?? key}
            </label>
            <input id={`fact-${key}`} className="f-input sm" value={values[key] ?? ''} onChange={(e) => setValues((v) => ({ ...v, [key]: e.target.value }))} placeholder="(해당 없음)" />
            {f?.evidence && (
              <p className="f-meta">
                근거: “{f.evidence}”{f.source ? ` · ${f.source}` : ''}
                {f.confidence != null && f.confidence < 0.6 ? ' · 확신 낮음' : ''}
              </p>
            )}
            {f?.conflict && f.conflict.length > 0 && (
              <div className="conflict">
                {f.conflict.map((c) => (
                  <button type="button" key={c} onClick={() => setValues((v) => ({ ...v, [key]: c }))}>
                    다른 자료: {c}
                  </button>
                ))}
              </div>
            )}
          </div>
        );
      })}

      {addable.length > 0 && (
        <div className="add-fact">
          <select
            aria-label="값 추가하기"
            value=""
            onChange={(e) => {
              const k = e.target.value;
              if (k) setExtra((x) => [...x, k]);
            }}
          >
            <option value="">+ 알고 있는 값 추가하기</option>
            {addable.map((k) => (
              <option key={k} value={k}>
                {FACT_LABELS[k]}
              </option>
            ))}
          </select>
        </div>
      )}

      <CtaBar>
        <Cta label="확인했어요" busy={busy} onClick={() => onAnswer('facts_ok', 'yes', { facts: Object.fromEntries(shown.map((k) => [k, values[k] ?? ''])) })} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 3~4. 질문 (후보 고르기 포함)

export function QuestionScreen({ screen, progress, busy, onAnswer }: { screen: S<'question'>; progress: number; busy: boolean; onAnswer: Answer }) {
  const [single, setSingle] = useState<string | null>(typeof screen.defaultValue === 'string' ? screen.defaultValue : null);
  const [multi, setMulti] = useState<string[]>(Array.isArray(screen.defaultValue) ? screen.defaultValue : []);
  const [text, setText] = useState('');

  const toggle = (v: string) =>
    setMulti((prev) => {
      if (v === 'none') return prev.includes('none') ? [] : ['none'];
      const next = prev.filter((x) => x !== 'none');
      return next.includes(v) ? next.filter((x) => x !== v) : [...next, v];
    });

  const submit = () => {
    if (screen.input === 'single_choice' && single) onAnswer(screen.stepKey, single);
    else if (screen.input === 'multi_choice') onAnswer(screen.stepKey, JSON.stringify(multi.filter((x) => x !== 'none')));
    else if (text.trim()) onAnswer(screen.stepKey, text.trim());
  };
  const ready = screen.input === 'single_choice' ? Boolean(single) : screen.input === 'multi_choice' ? multi.length > 0 : text.trim() !== '';

  return (
    <>
      <StepLabel index={progress} />
      {screen.note && <span className="flow-chip-note">{screen.note}</span>}
      <h1 className="flow-title">{screen.title}</h1>
      {screen.help ? <p className="flow-sub">{screen.help}</p> : <div style={{ height: 18 }} />}

      {(screen.input === 'single_choice' || screen.input === 'multi_choice') && (
        <div className="opts" role={screen.input === 'single_choice' ? 'radiogroup' : 'group'} aria-label={screen.title}>
          {screen.options.map((o) => {
            const on = screen.input === 'single_choice' ? single === o.value : multi.includes(o.value);
            return (
              <button
                key={o.value}
                type="button"
                role={screen.input === 'single_choice' ? 'radio' : 'checkbox'}
                aria-checked={on}
                className={`opt ${on ? 'on' : ''} ${screen.input === 'multi_choice' ? 'multi' : ''}`}
                onClick={() => (screen.input === 'single_choice' ? setSingle(o.value) : toggle(o.value))}
              >
                <span className="opt-mark">{on && <Check />}</span>
                <span className="opt-body">
                  <span className="opt-label">{o.label}</span>
                  {o.hint && <span className="opt-hint">{o.hint}</span>}
                </span>
                {o.badge && <span className="opt-badge">{o.badge}</span>}
              </button>
            );
          })}
        </div>
      )}

      {(screen.input === 'number' || screen.input === 'text') && (
        <div className="f-field f-unit">
          <input
            className="f-input"
            inputMode={screen.input === 'number' ? 'decimal' : 'text'}
            value={text}
            onChange={(e) => setText(screen.input === 'number' ? e.target.value.replace(/[^\d.]/g, '') : e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && ready && submit()}
            placeholder={screen.input === 'number' ? '숫자로 적어 주세요' : ''}
            autoFocus
            aria-label={screen.title}
          />
          {screen.unit && <span>{screen.unit}</span>}
        </div>
      )}

      <CtaBar>
        <Cta label="다음" busy={busy} disabled={!ready} onClick={submit} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 7. 빈 칸 채우기 (표시 초안 직전)

export function FillScreen({ screen, busy, onAnswer }: { screen: S<'fill'>; busy: boolean; onAnswer: Answer }) {
  const [text, setText] = useState('');
  const ex = screen.help && screen.help !== screen.name ? screen.help : null;
  return (
    <>
      <StepLabel index={6} />
      <span className="flow-chip-note">
        빈 칸 채우기 {screen.position}/{screen.total}
      </span>
      <h1 className="flow-title">{`표시사항의 '${screen.name}' 칸에\n들어갈 내용을 적어 주세요`}</h1>
      <p className="flow-sub">
        {screen.requirement === 'required' ? '필수 표시 항목이에요.' : `조건부 항목이에요${screen.condition ? ` (${screen.condition})` : ''}. 해당하지 않으면 넘어가세요.`} 지금 모르면 나중에 초안에서 채워도 돼요.
      </p>

      <div className="f-field">
        <label className="f-label" htmlFor="fill-input">
          {screen.name}
        </label>
        <input
          id="fill-input"
          className="f-input"
          value={text}
          maxLength={300}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && text.trim() && onAnswer(screen.stepKey, text.trim())}
          placeholder={ex ?? screen.placeholder ?? ''}
          autoFocus
        />
        {ex && <p className="f-meta">작성 예: {ex}</p>}
      </div>

      {screen.reference && (
        <div className="info-box" style={{ marginTop: 8 }}>
          <strong>자료 참고</strong>
          <p style={{ margin: 0, color: 'var(--text-sub)' }}>{screen.reference}</p>
        </div>
      )}

      <CtaBar>
        <button type="button" className="cta-sub" disabled={busy} onClick={() => onAnswer(screen.stepKey, '')}>
          나중에 채울게요
        </button>
        <Cta label="다음" busy={busy} disabled={!text.trim()} onClick={() => onAnswer(screen.stepKey, text.trim())} />
      </CtaBar>
    </>
  );
}

export function WaitScreen({ screen, busy, onAnswer, onBack }: { screen: S<'wait'>; busy: boolean; onAnswer: Answer; onBack: () => void }) {
  return (
    <>
      <StepLabel index={3} />
      <h1 className="flow-title">{screen.title}</h1>
      <div className="warn-box">
        <strong>확인이 필요해요</strong>
        {screen.message}
      </div>
      <p className="flow-sub">확인한 뒤 다시 답하면 더 정확해요. 모르는 채로 진행하면 초안에 "확인 필요"로 남겨 둘게요.</p>
      <CtaBar>
        <button type="button" className="cta-sub" onClick={onBack} disabled={busy}>
          다시 답할게요
        </button>
        <Cta label="모르는 채로 진행" busy={busy} onClick={() => onAnswer(screen.stepKey, 'skip')} />
      </CtaBar>
    </>
  );
}

export function NoMatchScreen({ screen, busy, onAnswer }: { screen: S<'no_match'>; busy: boolean; onAnswer: Answer }) {
  const [q, setQ] = useState('');
  return (
    <>
      <StepLabel index={2} />
      <h1 className="flow-title">{'품목표에서\n찾지 못했어요'}</h1>
      <p className="flow-sub">{screen.message}</p>
      {screen.tried.length > 0 && (
        <div className="doc-chips">
          {screen.tried.map((t) => (
            <span key={t} className="doc-chip">
              찾아본 이름 · <b>{t}</b>
            </span>
          ))}
        </div>
      )}
      <div className="f-field">
        <label className="f-label" htmlFor="research">
          다른 이름으로 찾기
        </label>
        <input
          id="research"
          className="f-input"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && q.trim() && onAnswer('search', q.trim())}
          placeholder="예: 가습기, 전기방향확산기"
          autoFocus
        />
      </div>
      <div className="info-box">
        <strong>참고해 주세요</strong>
        <ul>
          <li>상표명보다 제품을 부르는 일반 이름(예: "OO 미니팬" → "선풍기")이 잘 찾아져요.</li>
          <li>품목표 6개 분야 중 지금은 전기용품·생활용품·어린이제품이 들어 있어요. 화장품·생활화학제품·식품용 기구는 준비 중이에요.</li>
        </ul>
      </div>
      <CtaBar>
        <button type="button" className="cta-sub" disabled={busy} onClick={() => onAnswer('pick', 'none')}>
          전문가 확인 요청
        </button>
        <Cta label="다시 찾기" busy={busy} disabled={!q.trim()} onClick={() => onAnswer('search', q.trim())} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 5. 최신 원문 확인

export function SourceCheckScreen({ screen, busy, onAnswer }: { screen: S<'source_check'>; busy: boolean; onAnswer: Answer }) {
  return (
    <>
      <StepLabel index={4} />
      <h1 className="flow-title">{'판정 근거를\n확인해 주세요'}</h1>
      <p className="flow-sub">확정된 품목의 법령·고시가 지금도 유효한 최신 버전인지 확인해야 해요. 확인이 안 된 부분은 초안에 따로 표시돼요.</p>
      {screen.sources.map((s) => (
        <div className="card" key={s.item.code}>
          <div className="card-head">
            <strong>{s.item.name}</strong>
            <span className="tag blue">{ROLE_LABEL[s.role]}</span>
            {s.item.certType && <span className="tag">{CERT_LABEL[s.item.certType]}</span>}
            <span className="tag">{CATEGORY_LABEL[s.item.category]}</span>
          </div>
          <dl className="kv">
            <dt>근거 문서</dt>
            <dd>
              {s.url ? (
                <a href={s.url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--primary)' }}>
                  {s.doc ?? s.url}
                </a>
              ) : (
                (s.doc ?? '-')
              )}
              {s.page ? ` ${s.page}쪽` : ''}
            </dd>
            <dt>기준 판</dt>
            <dd>{s.edition ?? '-'}</dd>
            <dt>최신 확인</dt>
            <dd>{s.verifiedAt ? `${s.verifiedAt} 확인` : '아직 확인 안 됨'}</dd>
            {s.standard && (
              <>
                <dt>적용 기준</dt>
                <dd style={{ fontSize: 13, color: 'var(--text-sub)' }}>{s.standard.length > 160 ? `${s.standard.slice(0, 160)}…` : s.standard}</dd>
              </>
            )}
          </dl>
          {s.flags.length > 0 && (
            <ul className="flags">
              {s.flags.map((f) => (
                <li key={f}>{f}</li>
              ))}
            </ul>
          )}
        </div>
      ))}
      <CtaBar>
        <Cta label="확인했어요" busy={busy} onClick={() => onAnswer('source_ack', 'yes')} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 6. 추가 규칙 적용

export function RulesScreen({ screen, busy, onAnswer }: { screen: S<'rules'>; busy: boolean; onAnswer: Answer }) {
  return (
    <>
      <StepLabel index={5} />
      <h1 className="flow-title">{'이렇게 판정했어요'}</h1>
      <p className="flow-sub">여러 분야에 걸치면 표시를 무조건 다 붙이지 않고, 아래 방식으로 구분해서 처리해요.</p>

      <div className="ptypes">
        {screen.processTypes.map((t) => (
          <div key={t} className={`ptype ${t === 'review' ? 'review' : ''}`}>
            <b>{PROCESS_TYPE_INFO[t].title}</b>
            <span>{PROCESS_TYPE_INFO[t].desc}</span>
          </div>
        ))}
      </div>

      <h2 className="sec-title">적용하는 기준</h2>
      {screen.items.map((i) => (
        <div className="card" key={`${i.role}-${i.name}`}>
          <div className="card-head">
            <strong>{i.name}</strong>
            <span className={`tag ${i.role === 'primary' ? 'blue' : 'green'}`}>{ROLE_LABEL[i.role]}</span>
            {i.item?.certType && <span className="tag">{CERT_LABEL[i.item.certType]}</span>}
            {!i.item && <span className="tag amber">별도 판정 필요</span>}
          </div>
          <p style={{ margin: 0, fontSize: 14, color: 'var(--text-sub)' }}>{i.basis}</p>
        </div>
      ))}

      {screen.notes.length > 0 && (
        <>
          <h2 className="sec-title">조건에 따라 바뀐 점</h2>
          <ul className="plain-list">
            {screen.notes.map((n) => (
              <li key={n}>{n}</li>
            ))}
          </ul>
        </>
      )}

      {screen.escalations.length > 0 && (
        <div className="warn-box" style={{ marginTop: 24 }}>
          <strong>사람 검토가 필요한 부분</strong>
          <ul>
            {screen.escalations.map((e) => (
              <li key={e}>{e}</li>
            ))}
          </ul>
        </div>
      )}

      {screen.autoAnswered.length > 0 && (
        <details className="auto">
          <summary>자료로 자동 답한 질문 {screen.autoAnswered.length}개</summary>
          <ul className="plain-list" style={{ marginTop: 8 }}>
            {screen.autoAnswered.map((a) => (
              <li key={a.question}>
                {a.question} → <b>{a.answer}</b>
              </li>
            ))}
          </ul>
        </details>
      )}

      <CtaBar>
        <Cta label="표시 초안 만들기" busy={busy} onClick={() => onAnswer('rules_ack', 'yes')} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 7. 표시 초안

const ORIGIN_LABEL: Record<DraftRow['origin'], string> = {
  document: '자료에서 가져옴',
  fixed: '고정 표시',
  answer: '답변에서 가져옴',
  text_block: '가이드북 문구',
  empty: '입력 필요',
};

export function DraftScreen({ draft, onRestart }: { draft: Draft; onRestart: () => void }) {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(draft.rows.map((r) => [r.key, r.value])));
  const [copied, setCopied] = useState(false);

  const text = useMemo(
    () =>
      [
        `[품질 표시사항 초안] ${draft.productName}`,
        '',
        ...draft.rows.map((r) => {
          const v = values[r.key] || r.placeholder || '(입력 필요)';
          return v.includes('\n') ? `${r.name}:\n${v}` : `${r.name}: ${v}`;
        }),
        '',
        '— 확정 안 된 부분 —',
        ...draft.unresolved.map((u) => `· ${u}`),
      ].join('\n'),
    [draft, values],
  );

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      alert('복사하지 못했어요. 다운로드를 이용해 주세요.');
    }
  };
  const download = () => {
    const url = URL.createObjectURL(new Blob([text], { type: 'text/plain;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `표시사항초안_${draft.productName || '제품'}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const emptyCount = draft.rows.filter((r) => r.requirement === 'required' && !values[r.key]).length;

  return (
    <>
      <StepLabel index={6} />
      <h1 className="flow-title">{'표시 초안이\n완성됐어요'}</h1>
      <p className="flow-sub">
        <b>{draft.productName}</b> · 빈 칸 {emptyCount}개 · 확인할 부분 {draft.unresolved.length}개. 칸을 눌러 바로 고칠 수 있어요.
      </p>

      <div className="draft-head">
        {draft.processTypes.map((t) => (
          <span key={t} className={`tag ${t === 'review' ? 'amber' : 'blue'}`}>
            {PROCESS_TYPE_INFO[t].title}
          </span>
        ))}
        {draft.items.map((i) => (
          <span key={`${i.role}-${i.name}`} className="tag">
            {ROLE_LABEL[i.role]} · {i.name}
          </span>
        ))}
      </div>

      <div className="cert-cards">
        {draft.certSummary.map((c) => (
          <div key={c.item.code} className="cert-card">
            <b>
              {c.item.name} · {c.label}
            </b>
            {c.summary}
            <div style={{ marginTop: 6 }}>
              KC마크 {c.kcMark ? '표시' : '없음'} · 번호 {c.certNo ? '표시' : '없음'}
            </div>
          </div>
        ))}
      </div>

      <h2 className="sec-title">표시사항</h2>
      <div className="label-sheet">
        {draft.rows.map((r) => (
          <div className="label-row" key={r.key}>
            <div className="label-key">
              {r.name}
              {r.requirement !== 'required' && <small>{r.condition ? `조건부: ${r.condition}` : r.requirement === 'conditional' ? '조건부' : '권장'}</small>}
            </div>
            <div className="label-val">
              {r.multiline ? (
                <textarea
                  rows={Math.min(10, Math.max(2, (values[r.key] ?? '').split('\n').length))}
                  value={values[r.key] ?? ''}
                  placeholder={r.placeholder ?? r.help ?? '입력 필요'}
                  onChange={(e) => setValues((v) => ({ ...v, [r.key]: e.target.value }))}
                  aria-label={r.name}
                />
              ) : (
                <input value={values[r.key] ?? ''} placeholder={r.placeholder ?? r.help ?? '입력 필요'} onChange={(e) => setValues((v) => ({ ...v, [r.key]: e.target.value }))} aria-label={r.name} />
              )}
              <div className="label-meta">
                <span>{!values[r.key] ? ORIGIN_LABEL.empty : values[r.key] !== r.value ? '직접 입력' : ORIGIN_LABEL[r.origin]}</span>
                <span>위치: {r.location}</span>
                <span title={r.sources.map((s) => `${s.name} — ${s.basis}`).join('\n')}>근거: {r.sources.map((s) => `${s.name}(${s.basis})`).join(', ')}</span>
                {r.needsReview && <span style={{ color: '#ad6800' }}>원문 대조 필요</span>}
                {r.help && !values[r.key] && <span>도움말: {r.help}</span>}
              </div>
            </div>
          </div>
        ))}
      </div>

      {draft.displayMethods.length > 0 && (
        <>
          <h2 className="sec-title">표시 방법</h2>
          {draft.displayMethods.map((d) => (
            <div key={d.item} className="card">
              <div className="card-head">
                <strong style={{ fontSize: 15 }}>{d.item}</strong>
              </div>
              <ul className="plain-list">
                {d.lines.map((l) => (
                  <li key={l}>{l}</li>
                ))}
              </ul>
            </div>
          ))}
        </>
      )}

      {draft.unresolved.length > 0 && (
        <div className="warn-box" style={{ marginTop: 24 }}>
          <strong>확정 안 된 부분</strong>
          <ul>
            {draft.unresolved.map((u) => (
              <li key={u}>{u}</li>
            ))}
          </ul>
        </div>
      )}

      {draft.notes.length > 0 && (
        <>
          <h2 className="sec-title">판정 메모</h2>
          <ul className="plain-list">
            {draft.notes.map((n) => (
              <li key={n}>{n}</li>
            ))}
          </ul>
        </>
      )}

      <CtaBar>
        <button type="button" className="cta-sub" onClick={onRestart}>
          처음부터
        </button>
        <button type="button" className="cta-sub" onClick={copy}>
          {copied ? '복사됨 ✓' : '복사'}
        </button>
        <Cta label="다운로드" onClick={download} />
      </CtaBar>
    </>
  );
}

// ------------------------------------------------------------------ 끝 (대상 아님 / 사람 검토)

export function EndScreen({ screen, onBack, onRestart }: { screen: S<'end'>; onBack: () => void; onRestart: () => void }) {
  return (
    <>
      <div className="end-icon" aria-hidden="true">
        {screen.kind === 'out_of_scope' ? '🚫' : '🧑‍💼'}
      </div>
      <h1 className="flow-title">{screen.title}</h1>
      <p className="flow-sub">{screen.message}</p>
      {screen.item && (
        <div className="card">
          <div className="card-head">
            <strong>{screen.item.name}</strong>
            <span className="tag">{CATEGORY_LABEL[screen.item.category]}</span>
            {screen.item.certType && <span className="tag">{CERT_LABEL[screen.item.certType]}</span>}
          </div>
        </div>
      )}
      {screen.reasons.length > 0 && (
        <div className="info-box">
          <strong>판정 근거</strong>
          <ul>
            {screen.reasons.map((r) => (
              <li key={r}>{r}</li>
            ))}
          </ul>
        </div>
      )}
      <CtaBar>
        <button type="button" className="cta-sub" onClick={onBack}>
          답 바꾸기
        </button>
        {screen.kind === 'review' ? (
          <a className="btn-primary cta" href="/support" style={{ display: 'inline-flex' }}>
            전문가에게 문의하기
          </a>
        ) : (
          <Cta label="다른 제품 하기" onClick={onRestart} />
        )}
      </CtaBar>
    </>
  );
}
