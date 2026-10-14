import { useState, type SyntheticEvent } from 'react';

interface Props {
  placeholder?: string;
}

export default function SearchBar({ placeholder = '제품을 검색해보세요.' }: Props) {
  const [query, setQuery] = useState('');

  const onSubmit = (e: SyntheticEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    // TODO: 검색 API 연동
    alert(`"${query.trim()}" 검색 기능은 준비 중입니다.`);
  };

  return (
    <form className="search-bar" role="search" onSubmit={onSubmit}>
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={placeholder}
        aria-label="제품 검색"
      />
      <button type="submit" className="btn-primary">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        검색
      </button>
    </form>
  );
}
