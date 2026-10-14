// @ts-check
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import cloudflare from '@astrojs/cloudflare';

// 페이지는 정적으로 미리 만들고(SEO), /api/* 만 Cloudflare Worker 에서 실행한다 (Gemini 키·D1 은 서버 전용)
export default defineConfig({
  integrations: [react()],
  adapter: cloudflare({
    imageService: 'passthrough', // astro:assets 이미지 변환을 쓰지 않음 (Images 바인딩 불필요)
  }),
  session: false, // Astro 세션 기능 미사용 (KV 바인딩 불필요). 흐름 세션은 D1 에 저장
});
