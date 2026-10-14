import { useEffect, useState } from 'react';

const KEYWORDS = ['선풍기', '보조배터리', '가습기', '우산', '텀블러', '유아 매트', '전기장판', '헤어드라이어', '블록 완구', '무선 이어폰'];

export default function RealtimeRanking() {
  const [index, setIndex] = useState(0);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (open) return;
    const id = setInterval(() => setIndex((i) => (i + 1) % KEYWORDS.length), 2500);
    return () => clearInterval(id);
  }, [open]);

  return (
    <div className={`ranking ${open ? 'open' : ''}`}>
      <button type="button" className="ranking-head" onClick={() => setOpen((v) => !v)} aria-expanded={open}>
        <span className="ranking-label">
          <i aria-hidden="true" />
          실시간
        </span>
        <span className="ranking-current" key={index}>
          <b>{index + 1}</b>
          {KEYWORDS[index]}
        </span>
        <svg className="chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4">
          <path d="m6 9 6 6 6-6" />
        </svg>
      </button>
      {open && (
        <ol className="ranking-list">
          {KEYWORDS.map((k, i) => (
            <li key={k}>
              <a href="#">
                <b>{i + 1}</b>
                {k}
              </a>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
