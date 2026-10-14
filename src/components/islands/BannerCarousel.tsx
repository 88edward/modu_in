import { useCallback, useEffect, useState } from 'react';

interface Slide {
  left: string;
  right: string[];
  bg: string;
}

const SLIDES: Slide[] = [
  {
    left: '문서만 올리면',
    right: ['품질 표시사항', '자동 생성'],
    bg: 'linear-gradient(100deg, #0a3d91 0%, #0b6cf0 100%)',
  },
  {
    left: '기존 회원',
    right: ['회사 가입', '바로가기'],
    bg: 'linear-gradient(100deg, #1f5f9f 0%, #3a9ad6 100%)',
  },
];

export default function BannerCarousel() {
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  const go = useCallback((dir: number) => setIndex((i) => (i + dir + SLIDES.length) % SLIDES.length), []);

  useEffect(() => {
    if (paused) return;
    const id = setInterval(() => go(1), 5000);
    return () => clearInterval(id);
  }, [paused, go]);

  return (
    <div
      className="banner"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      aria-roledescription="carousel"
    >
      <div className="banner-track" style={{ transform: `translateX(-${index * 100}%)` }}>
        {SLIDES.map((s, i) => (
          <div
            key={i}
            className="banner-slide"
            style={{ background: s.bg }}
            aria-hidden={i !== index}
            aria-label={`${i + 1} / ${SLIDES.length}`}
          >
            <span className="banner-left">{s.left}</span>
            <svg className="banner-arrow" viewBox="0 0 110 90" aria-hidden="true">
              <path d="M0 30h58V0l52 45-52 45V60H0z" fill="#fff" />
            </svg>
            <span className="banner-right">
              {s.right.map((line) => (
                <span key={line}>{line}</span>
              ))}
            </span>
          </div>
        ))}
      </div>
      <button type="button" className="banner-nav prev" onClick={() => go(-1)} aria-label="이전 배너">
        <svg viewBox="0 0 10 16"><path d="M9 1 2 8l7 7" fill="#fff" /></svg>
      </button>
      <button type="button" className="banner-nav next" onClick={() => go(1)} aria-label="다음 배너">
        <svg viewBox="0 0 10 16"><path d="m1 1 7 7-7 7" fill="#fff" /></svg>
      </button>
      <div className="banner-dots">
        {SLIDES.map((_, i) => (
          <button
            key={i}
            type="button"
            className={i === index ? 'on' : ''}
            onClick={() => setIndex(i)}
            aria-label={`${i + 1}번 배너로 이동`}
          />
        ))}
      </div>
    </div>
  );
}
