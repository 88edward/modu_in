import { useEffect, useRef, useState } from 'react';

const LANGS = ['한국어', 'English', '中文', '日本語'];

export default function LanguageSelect() {
  const [open, setOpen] = useState(false);
  const [lang, setLang] = useState(LANGS[0]);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('click', onClick);
    return () => document.removeEventListener('click', onClick);
  }, []);

  return (
    <div ref={ref} style={{ position: 'relative' }}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 4,
          border: 0,
          background: 'none',
          color: '#6b7280',
          fontSize: 14,
          padding: 0,
        }}
      >
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
          <circle cx="12" cy="12" r="9" />
          <path d="M3 12h18M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9S9.5 5.7 12 3z" />
        </svg>
        {lang}
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
          <path d="m6 9 6 6 6-6" />
        </svg>
      </button>
      {open && (
        <ul
          role="listbox"
          style={{
            position: 'absolute',
            right: 0,
            top: 'calc(100% + 10px)',
            margin: 0,
            padding: 6,
            listStyle: 'none',
            background: '#fff',
            border: '1px solid #e5e8ee',
            borderRadius: 10,
            boxShadow: '0 8px 24px rgba(15,23,42,.1)',
            minWidth: 110,
          }}
        >
          {LANGS.map((l) => (
            <li key={l}>
              <button
                type="button"
                role="option"
                aria-selected={l === lang}
                onClick={() => {
                  setLang(l);
                  setOpen(false);
                }}
                style={{
                  width: '100%',
                  textAlign: 'left',
                  border: 0,
                  borderRadius: 6,
                  padding: '8px 10px',
                  fontSize: 14,
                  background: l === lang ? '#e8f1ff' : 'transparent',
                  color: l === lang ? '#0b6cf0' : '#111827',
                }}
              >
                {l}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
