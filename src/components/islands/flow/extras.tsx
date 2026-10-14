// 진행 화면 보조 UI: 위쪽 질문 기록 선 · 왼쪽 표시사항 미리보기 · 트리 보기
import { useEffect, useRef, useState } from 'react';
import { FLOW_STEPS, type HistoryStep, type Preview, type TrailStep, type TreeNode } from '../../../lib/flow-types';

// ------------------------------------------------------------------ 질문 기록 선

/** 답 하나 = 선 하나. 글자 없이 선만 보이고, 누르면 그 질문으로 돌아간다 (마우스를 올리면 질문·답이 툴팁으로) */
export function HistoryBar({ history, busy, onGoto }: { history: HistoryStep[]; busy: boolean; onGoto: (index: number) => void }) {
  if (!history.length) return null;
  return (
    <nav className="hist" aria-label="지금까지 한 질문 (누르면 그 질문으로 돌아가요)">
      <ol>
        {history.map((h) => (
          <li key={h.index}>
            <button
              type="button"
              className={`hist-seg s${h.stage}`}
              disabled={busy}
              onClick={() => onGoto(h.index)}
              title={`${h.title}\n→ ${h.answer}\n(${FLOW_STEPS[h.stage]} · 누르면 이 질문으로 돌아가요)`}
              aria-label={`${h.index + 1}번째 답: ${h.title} — ${h.answer}. 이 질문으로 돌아가기`}
            />
          </li>
        ))}
        <li aria-current="step">
          <span className="hist-seg now" title="지금 질문" />
        </li>
      </ol>
    </nav>
  );
}

// ------------------------------------------------------------------ 표시사항 미리보기

/** 답할 때마다 채워지는 표시사항 최종본 미리보기. 방금 채워진 칸은 잠깐 반짝인다 */
export function PreviewPanel({ preview, open, onClose }: { preview: Preview; open: boolean; onClose: () => void }) {
  const prev = useRef<Map<string, string> | null>(null);
  const [fresh, setFresh] = useState<Set<string>>(new Set());

  useEffect(() => {
    const before = prev.current;
    const now = new Map(preview.rows.map((r) => [r.key, r.value]));
    if (before) {
      const changed = new Set<string>();
      for (const [k, v] of now) if (v && before.get(k) !== v) changed.add(k);
      for (const k of now.keys()) if (!before.has(k)) changed.add(k);
      setFresh(changed);
      const t = window.setTimeout(() => setFresh(new Set()), 1800);
      prev.current = now;
      return () => window.clearTimeout(t);
    }
    prev.current = now;
  }, [preview]);

  const filled = preview.rows.filter((r) => r.value).length;

  return (
    <aside className={`pv ${open ? 'open' : ''}`} aria-label="표시사항 미리보기">
      <div className="pv-head">
        <div>
          <p className="pv-kicker">표시사항 미리보기</p>
          <strong>{preview.title}</strong>
          {preview.subtitle && <span>{preview.subtitle}</span>}
        </div>
        <button type="button" className="pv-close" onClick={onClose} aria-label="미리보기 닫기">
          ×
        </button>
      </div>
      <div className="pv-meter" aria-label={`${preview.rows.length}칸 중 ${filled}칸 채워짐`}>
        <i style={{ width: `${preview.rows.length ? (filled / preview.rows.length) * 100 : 0}%` }} />
      </div>
      <p className="pv-count">
        {preview.rows.length}칸 중 <b>{filled}칸</b> 채워짐
      </p>
      <dl className="pv-sheet">
        {preview.rows.map((r) => (
          <div key={r.key} className={`pv-row ${r.value ? 'on' : ''} ${fresh.has(r.key) ? 'fresh' : ''}`}>
            <dt>
              {r.name}
              {r.requirement !== 'required' && <small>조건부</small>}
            </dt>
            <dd className={r.multiline ? 'multi' : ''}>{r.value ? r.value : <span className="pv-empty">{r.placeholder ?? '빈칸'}</span>}</dd>
          </div>
        ))}
      </dl>
    </aside>
  );
}

// ------------------------------------------------------------------ 트리 보기

function TreeBranch({ node }: { node: TreeNode }) {
  const here = node.state === 'path' && (!node.children || node.children.every((c) => c.state !== 'path'));
  return (
    <li>
      {node.edge && <span className="tr-edge">{node.edge}</span>}
      <div className={`tr-node k-${node.kind} st-${node.state} ${here ? 'here' : ''}`} data-here={here || undefined}>
        <b>{node.label}</b>
        {node.sub && <small>{node.sub}</small>}
        {here && <em>지금 여기</em>}
      </div>
      {node.children && node.children.length > 0 && (
        <ul>
          {node.children.map((c) => (
            <TreeBranch key={c.id} node={c} />
          ))}
        </ul>
      )}
    </li>
  );
}

export function TreeModal({ tree, trail, onClose }: { tree: TreeNode; trail: TrailStep[]; onClose: () => void }) {
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    // 지금 위치가 보이도록 스크롤
    const here = box.current?.querySelector('[data-here]');
    here?.scrollIntoView({ block: 'center', inline: 'center' });
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="tr-overlay" role="dialog" aria-modal="true" aria-label="판정 트리" onClick={onClose}>
      <div className="tr-panel" onClick={(e) => e.stopPropagation()}>
        <div className="tr-top">
          <div>
            <strong>판정 트리</strong>
            <span>품목표 전체에서 지금 답을 따라 어느 가지까지 왔는지 보여줘요. 정해지지 않은 가지는 접어 두었어요.</span>
          </div>
          <button type="button" className="pv-close" onClick={onClose} aria-label="트리 닫기">
            ×
          </button>
        </div>
        <div className="tr-legend" aria-hidden="true">
          <span className="lg-path">지금 경로</span>
          <span className="lg-cand">후보</span>
          <span className="lg-muted">접어 둔 가지</span>
        </div>
        <div className="tr-scroll" ref={box}>
          <div className="tr">
            <ul>
              <TreeBranch node={tree} />
            </ul>
          </div>
        </div>
        {trail.length > 0 && (
          <div className="tr-trail">
            <strong>판정 경로</strong>
            <ol>
              {trail.map((t, i) => (
                <li key={i}>
                  <b>{t.label}</b>
                  <span>{t.detail}</span>
                </li>
              ))}
            </ol>
          </div>
        )}
      </div>
    </div>
  );
}
