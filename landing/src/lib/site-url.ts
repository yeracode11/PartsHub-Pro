/** Публичный адрес сайта из NEXT_PUBLIC_SITE_URL (без завершающего слэша). Пока домена нет — undefined. */
export const siteUrl = process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/+$/, '') || undefined;
