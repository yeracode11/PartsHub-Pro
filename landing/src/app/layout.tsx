import type { Metadata, Viewport } from 'next';
import { Manrope, Unbounded } from 'next/font/google';
import { siteUrl } from '@/lib/site-url';
import './globals.css';

const manrope = Manrope({
  subsets: ['cyrillic', 'latin'],
  display: 'swap',
  variable: '--font-sans',
});

const unbounded = Unbounded({
  subsets: ['cyrillic', 'latin'],
  weight: ['500', '600', '700'],
  display: 'swap',
  variable: '--font-display',
});

const title = 'Jolda CRM — учёт и продажи для авторазборок и СТО в Казахстане';
const description =
  'Склад, продажи, клиенты, запись и заказ-наряды в одном приложении для авторазборок, СТО и магазинов запчастей. Работает без интернета. Запросите демо.';

export const metadata: Metadata = {
  metadataBase: siteUrl ? new URL(siteUrl) : undefined,
  title,
  description,
  applicationName: 'Jolda CRM',
  keywords: [
    'программа для авторазборки',
    'учёт склада автозапчастей',
    'программа для СТО',
    'CRM для автосервиса',
    'учёт запчастей Казахстан',
  ],
  alternates: { canonical: '/' },
  robots: siteUrl ? { index: true, follow: true } : { index: false, follow: false },
  openGraph: {
    title: 'Jolda CRM — учёт и продажи для автобизнеса',
    description: 'Склад, продажи, клиенты, запись и заказ-наряды в одном приложении. Запросите демо.',
    url: '/',
    siteName: 'Jolda CRM',
    locale: 'ru_KZ',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Jolda CRM — учёт и продажи для автобизнеса',
    description: 'Склад, продажи, клиенты, запись и заказ-наряды в одном приложении.',
  },
  formatDetection: { telephone: false },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#ffffff',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" className={`${manrope.variable} ${unbounded.variable}`}>
      <body>{children}</body>
    </html>
  );
}
