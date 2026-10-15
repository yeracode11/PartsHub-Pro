import type { MetadataRoute } from 'next';
import { siteUrl } from '@/lib/site-url';

/**
 * Без NEXT_PUBLIC_SITE_URL (черновик, превью, localhost) индексация закрыта,
 * чтобы тестовый адрес не попал в поиск. С доменом — открыта, кроме /api.
 */
export default function robots(): MetadataRoute.Robots {
  if (!siteUrl) return { rules: { userAgent: '*', disallow: '/' } };
  return {
    rules: { userAgent: '*', allow: '/', disallow: '/api/' },
    sitemap: `${siteUrl}/sitemap.xml`,
    host: siteUrl,
  };
}
