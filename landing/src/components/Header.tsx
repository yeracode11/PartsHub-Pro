'use client';

import { useState } from 'react';
import { brand, nav } from '@/content/site';

export function Header() {
  const [open, setOpen] = useState(false);
  return (
    <header className="header">
      <div className="container header-inner">
        <a href="#top" className="brand" aria-label={`${brand.name} — наверх`}>
          <img src="/logo.svg" alt="Vinly" width={99} height={30} className="brand-mark" />
          <span className="brand-name" aria-hidden="true">CRM</span>
        </a>
        <nav className="nav" aria-label="Разделы страницы">
          {nav.map((i) => (
            <a key={i.href} href={i.href}>{i.label}</a>
          ))}
        </nav>
        <a href="#demo" className="btn btn-primary header-cta">Запросить демо</a>
        <button
          type="button"
          className="menu-btn"
          aria-label={open ? 'Закрыть меню' : 'Открыть меню'}
          aria-expanded={open}
          aria-controls="mobile-nav"
          onClick={() => setOpen((v) => !v)}
        >
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
            {open ? <path d="M4 4l12 12M16 4L4 16" /> : <path d="M3 6h14M3 10h14M3 14h14" />}
          </svg>
        </button>
      </div>
      <div id="mobile-nav" className="mobile-nav" data-open={open}>
        {nav.map((i) => (
          <a key={i.href} href={i.href} onClick={() => setOpen(false)}>{i.label}</a>
        ))}
        <a href="#demo" className="btn btn-primary" onClick={() => setOpen(false)}>Запросить демо</a>
      </div>
    </header>
  );
}
