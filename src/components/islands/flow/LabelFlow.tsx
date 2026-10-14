// 표시사항 생성 흐름 — 한 화면에 한 단계. 서버(/api/flow)가 다음 화면을 정하고, 여기서는 그리기만 한다.
// 브라우저 '뒤로'와 상단 ← 버튼은 같은 동작(마지막 답 취소)을 한다.
import { useCallback, useEffect, useRef, useState } from 'react';
import { FLOW_STEPS, type FlowReply, type FlowResponse } from '../../../lib/flow-types';
import {
  DraftScreen,
  EndScreen,
  FactsScreen,
  FillScreen,
  LoadingScreen,
  NoMatchScreen,
  QuestionScreen,
  RulesScreen,
  SourceCheckScreen,
  UploadScreen,
  WaitScreen,
  type Answer,
} from './screens';
import { HistoryBar, PreviewPanel, TreeModal } from './extras';

const SESSION_KEY = 'modu.label.session';
const store = {
  get: () => {
    try {
      return sessionStorage.getItem(SESSION_KEY);
    } catch {
      return null;
    }
  },
  set: (v: string | null) => {
    try {
      if (v) sessionStorage.setItem(SESSION_KEY, v);
      else sessionStorage.removeItem(SESSION_KEY);
    } catch {
      /* 저장 불가 환경이면 새로고침 시 처음부터 */
    }
  },
};

type View = { kind: 'boot' } | { kind: 'upload' } | { kind: 'reading' } | { kind: 'screen'; res: FlowResponse };

async function call(body: FormData | Record<string, unknown>): Promise<FlowReply> {
  const isForm = body instanceof FormData;
  const res = await fetch('/api/flow', {
    method: 'POST',
    body: isForm ? body : JSON.stringify(body),
    headers: isForm ? undefined : { 'content-type': 'application/json' },
  });
  try {
    return (await res.json()) as FlowReply;
  } catch {
    return { error: `서버 응답 오류 (${res.status})` };
  }
}

export default function LabelFlow() {
  const [view, setView] = useState<View>({ kind: 'boot' });
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [readPhase, setReadPhase] = useState(0);
  const [treeOpen, setTreeOpen] = useState(false);
  const [previewOpen, setPreviewOpen] = useState(false); // 좁은 화면에서만 쓰는 펼침 상태
  const sessionRef = useRef<string | null>(null);
  const busyRef = useRef(false);

  const flash = useCallback((msg: string) => {
    setToast(msg);
    window.setTimeout(() => setToast((t) => (t === msg ? null : t)), 4000);
  }, []);

  const toUpload = useCallback(() => {
    sessionRef.current = null;
    store.set(null);
    setView({ kind: 'upload' });
  }, []);

  /** 서버 응답 반영 */
  const apply = useCallback(
    (reply: FlowReply) => {
      if ('error' in reply) {
        flash(reply.error);
        return false;
      }
      if ('restart' in reply) {
        toUpload();
        return false;
      }
      sessionRef.current = reply.sessionId;
      store.set(reply.sessionId);
      setView({ kind: 'screen', res: reply });
      window.scrollTo({ top: 0 });
      return true;
    },
    [flash, toUpload],
  );

  const run = useCallback(async (fn: () => Promise<void>) => {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      await fn();
    } catch {
      flash('네트워크 오류가 생겼어요. 다시 시도해 주세요.');
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  }, [flash]);

  // 처음 열 때: 진행 중인 세션이 있으면 이어서
  useEffect(() => {
    const sid = store.get();
    if (!sid) {
      setView({ kind: 'upload' });
      return;
    }
    call({ action: 'state', sessionId: sid })
      .then((r) => apply(r))
      .catch(() => setView({ kind: 'upload' }));
  }, [apply]);

  const back = useCallback(() => {
    const sid = sessionRef.current;
    if (!sid) return;
    void run(async () => {
      apply(await call({ action: 'back', sessionId: sid }));
    });
  }, [apply, run]);

  // 브라우저 뒤로 = 마지막 답 취소. 흐름 중에는 기록 한 칸(sentinel)을 계속 유지해 페이지를 벗어나지 않게 한다.
  useEffect(() => {
    history.pushState({ flow: true }, '');
    const onPop = () => {
      if (!sessionRef.current) return; // 업로드 화면: 한 번 더 누르면 이전 페이지로
      history.pushState({ flow: true }, '');
      back();
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, [back]);

  const start = (name: string, files: File[]) =>
    run(async () => {
      const fd = new FormData();
      fd.set('productName', name);
      files.forEach((f) => fd.append('files', f));
      if (files.length) {
        setView({ kind: 'reading' });
        setReadPhase(0);
      }
      const timers = files.length ? [window.setTimeout(() => setReadPhase(1), 5000), window.setTimeout(() => setReadPhase(2), 14000)] : [];
      try {
        const ok = apply(await call(fd));
        if (!ok) setView((v) => (v.kind === 'reading' ? { kind: 'upload' } : v));
      } finally {
        timers.forEach(clearTimeout);
      }
    });

  /** 위쪽 기록 선: index 번째 답으로 돌아가기 */
  const goto = (index: number) => {
    const sid = sessionRef.current;
    if (!sid) return;
    void run(async () => {
      apply(await call({ action: 'goto', sessionId: sid, index }));
    });
  };

  const answer: Answer = (key, value, extra) => {
    const sid = sessionRef.current;
    if (!sid) return;
    void run(async () => {
      apply(await call({ action: 'answer', sessionId: sid, key, value, ...extra }));
    });
  };

  const restart = () => {
    if (confirm('처음부터 다시 할까요? 지금까지의 답은 사라져요.')) toUpload();
  };

  // ---------------------------------------------------------------- 그리기
  const progress = view.kind === 'screen' ? view.res.progress : view.kind === 'reading' ? 1 : 0;
  const screen = view.kind === 'screen' ? view.res.screen : null;
  const wide = screen?.type === 'draft';
  const canBack = view.kind === 'screen';
  const res = view.kind === 'screen' ? view.res : null;
  // 최종 초안 화면에서는 초안 자체가 보이므로 미리보기를 숨긴다
  const preview = res && screen?.type !== 'draft' ? res.preview : null;

  return (
    <div className={`flow ${wide ? 'wide' : ''}`}>
      <header className="flow-top">
        <div className="flow-top-inner">
          <button
            type="button"
            className="flow-icon-btn"
            aria-label="이전"
            disabled={!canBack || busy}
            onClick={back}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
              <path d="m15 5-7 7 7 7" />
            </svg>
          </button>
          <a className="flow-top-title" href="/label" aria-label="표시사항 생성 소개로">
            <svg width="20" height="20" viewBox="0 0 32 32" aria-hidden="true">
              <path d="M3 27V5h5.5l5.5 8.5L19.5 5H21v22h-5.5V15.5l-4 6h-2l-4-6V27z" fill="#8a94a6" />
              <rect x="23.5" y="5" width="5.5" height="14" rx="1.2" fill="#0b2a6b" />
              <rect x="23.5" y="21.5" width="5.5" height="5.5" rx="1.2" fill="#0b2a6b" />
            </svg>
            <b style={{ fontSize: 15, color: '#0b2a6b', letterSpacing: '-0.03em' }}>표시사항 생성</b>
          </a>
          <a className="flow-ask" href="/support">
            문의하기
          </a>
        </div>
        <div
          className="flow-progress"
          role="progressbar"
          aria-valuemin={1}
          aria-valuemax={FLOW_STEPS.length}
          aria-valuenow={progress + 1}
          aria-label={`${FLOW_STEPS.length}단계 중 ${progress + 1}단계: ${FLOW_STEPS[progress]}`}
        >
          <i style={{ width: `${((progress + 1) / FLOW_STEPS.length) * 100}%` }} />
        </div>
        {res && <HistoryBar history={res.history} busy={busy} onGoto={goto} />}
      </header>

      {preview && <PreviewPanel preview={preview} open={previewOpen} onClose={() => setPreviewOpen(false)} />}

      {res && (
        <div className="flow-tools">
          {preview && (
            <button type="button" className="tool-btn pv-toggle" onClick={() => setPreviewOpen((v) => !v)} aria-expanded={previewOpen}>
              미리보기
            </button>
          )}
          <button type="button" className="tool-btn" onClick={() => setTreeOpen(true)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true">
              <rect x="9" y="2" width="6" height="5" rx="1" />
              <rect x="2" y="17" width="6" height="5" rx="1" />
              <rect x="16" y="17" width="6" height="5" rx="1" />
              <path d="M12 7v5M5 17v-3h14v3" />
            </svg>
            트리 보기
          </button>
        </div>
      )}
      {res && treeOpen && <TreeModal tree={res.tree} trail={res.trail} onClose={() => setTreeOpen(false)} />}

      <main className="flow-main" key={view.kind === 'screen' ? `${screen!.type}-${'stepKey' in screen! ? screen.stepKey : ''}` : view.kind}>
        {view.kind === 'boot' && <div className="loading"><div className="big-spin" /></div>}
        {/* 자료를 못 읽는 등 서버 안내는 이 화면에 머무는 동안 계속 보여준다 */}
        {view.kind === 'screen' && view.res.notice && (
          <div className="warn-box" role="alert">
            <strong>확인해 주세요</strong>
            {view.res.notice}
          </div>
        )}
        {view.kind === 'upload' && <UploadScreen busy={busy} onStart={start} />}
        {view.kind === 'reading' && <LoadingScreen phase={readPhase} />}
        {screen?.type === 'facts' && <FactsScreen screen={screen} busy={busy} onAnswer={answer} />}
        {screen?.type === 'question' && <QuestionScreen screen={screen} progress={view.kind === 'screen' ? view.res.progress : 3} busy={busy} onAnswer={answer} />}
        {screen?.type === 'wait' && <WaitScreen screen={screen} busy={busy} onAnswer={answer} onBack={back} />}
        {screen?.type === 'no_match' && <NoMatchScreen screen={screen} busy={busy} onAnswer={answer} />}
        {screen?.type === 'source_check' && <SourceCheckScreen screen={screen} busy={busy} onAnswer={answer} />}
        {screen?.type === 'rules' && <RulesScreen screen={screen} busy={busy} onAnswer={answer} />}
        {screen?.type === 'fill' && <FillScreen screen={screen} busy={busy} onAnswer={answer} />}
        {screen?.type === 'draft' && <DraftScreen draft={screen.draft} onRestart={restart} />}
        {screen?.type === 'end' && <EndScreen screen={screen} onBack={back} onRestart={toUpload} />}
      </main>

      {toast && (
        <div className="toast" role="alert">
          {toast}
        </div>
      )}
    </div>
  );
}
