import { DesktopTabs } from '@/components/DesktopTabs';
import { Header } from '@/components/Header';
import { Icon } from '@/components/Icon';
import { LeadForm } from '@/components/LeadForm';
import Image from 'next/image';
import { PhoneFrame } from '@/components/PhoneFrame';
import { StickyCta } from '@/components/StickyCta';
import { siteUrl } from '@/lib/site-url';
import { audience, brand, extras, faq, features, form, hero, showDesktop, steps } from '@/content/site';

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareApplication',
      name: brand.name,
      applicationCategory: 'BusinessApplication',
      operatingSystem: 'iOS, Android, Windows, macOS',
      inLanguage: 'ru',
      description: hero.lead,
      ...(siteUrl ? { url: siteUrl } : {}),
    },
    {
      '@type': 'FAQPage',
      mainEntity: faq.map((i) => ({
        '@type': 'Question',
        name: i.q,
        acceptedAnswer: { '@type': 'Answer', text: i.a },
      })),
    },
  ],
};

export default function Home() {
  return (
    <>
      <Header />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }}
      />
      <main id="top">
        <section className="hero">
          <div className="container hero-grid">
            <div>
              <h1>{hero.title}</h1>
              <p className="lead">{hero.lead}</p>
              <div className="hero-actions">
                <a href="#demo" className="btn btn-primary">{hero.primaryCta}</a>
                <a href="#warehouse" className="btn btn-link">{hero.secondaryCta}<span aria-hidden="true">→</span></a>
              </div>
              <ul className="hero-facts">
                {hero.facts.map((f) => (
                  <li key={f}><Icon name="check" size={18} />{f}</li>
                ))}
              </ul>
            </div>
            <div className="hero-visual">
              <PhoneFrame
                className="phone-a"
                name="parts-dashboard"
                alt="Дашборд Vinly Business: поступило за месяц, продано, долги клиентов, график продаж"
                priority
                sizes="(max-width: 960px) 250px, 252px"
              />
              <PhoneFrame
                className="phone-b"
                name="parts-warehouse"
                alt="Экран «Товары» в Vinly Business"
                priority
                sizes="(max-width: 960px) 250px, 252px"
              />
            </div>
          </div>
        </section>

        <section id="audience" className="section">
          <div className="container">
            <div className="section-head">
              <h2>{audience.title}</h2>
              <p>{audience.lead}</p>
            </div>
            <div className="cards-3">
              {audience.items.map((i) => (
                <a key={i.title} href={i.href} className="card card-link">
                  <span className="icon-tile"><Icon name={i.icon} /></span>
                  <h3>{i.title}</h3>
                  <p>{i.text}</p>
                  <span className="card-more">Подробнее<span aria-hidden="true">→</span></span>
                </a>
              ))}
            </div>
          </div>
        </section>

        <section id="modules" className="section section-soft modules">
          <div className="container">
            <div className="section-head">
              <h2>Что внутри</h2>
              <p>Пять областей работы. Откройте нужную: ниже по каждой — экраны и список возможностей.</p>
            </div>
            <ul className="module-grid">
              {features.map((f) => (
                <li key={f.id}>
                  <a href={`#${f.id}`} className="module">
                    <span className="icon-tile"><Icon name={f.icon} /></span>
                    <span className="module-title">{f.label}</span>
                    <span className="module-text">{f.summary}</span>
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {features.map((f, idx) => (
          <section
            key={f.id}
            id={f.id}
            className={`section section-${f.tone}`}
          >
            <div className="container feature" data-flip={idx % 2 === 1}>
              <div className="feature-text">
                <p className="eyebrow"><span>{String(idx + 1).padStart(2, '0')}</span>{f.label}</p>
                <h2>{f.title}</h2>
                <p className="lead">{f.lead}</p>
                <ul className="points">
                  {f.points.map((p) => (
                    <li key={p}>{p}</li>
                  ))}
                </ul>
              </div>
              <div className={`feature-visual ${f.screens.length === 1 ? 'single' : ''}`}>
                {f.screens.map((s) => (
                  <PhoneFrame key={s.name} name={s.name} alt={s.alt} caption={s.caption} captionFirst />
                ))}
              </div>
            </div>
          </section>
        ))}

        {showDesktop && (
        <section id="desktop" className="section section-soft">
          <div className="container">
            <div className="section-head">
              <h2>И на компьютере</h2>
              <p>Те же данные в окне для Windows и macOS: таблицы, боковое меню и большие экраны для кассы и записи.</p>
            </div>
            <DesktopTabs
              shots={features.flatMap((f) =>
                f.desktop ? [{ id: f.id, label: f.label, name: f.desktop.name, alt: f.desktop.alt, caption: f.desktop.caption }] : [],
              )}
            />
          </div>
        </section>
        )}

        <section className="section">
          <div className="container">
            <div className="section-head">
              <h2>{extras.title}</h2>
            </div>
            <div className="cards-3">
              {extras.items.map((i) => (
                <article key={i.title} className="card">
                  <span className="icon-tile"><Icon name={i.icon} /></span>
                  <h3>{i.title}</h3>
                  <p>{i.text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="section section-tint">
          <div className="container">
            <div className="section-head">
              <h2>{steps.title}</h2>
            </div>
            <div className="steps">
              {steps.items.map((s) => (
                <div key={s.title} className="step">
                  <h3>{s.title}</h3>
                  <p>{s.text}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="faq" className="section">
          <div className="container">
            <div className="section-head">
              <h2>Частые вопросы</h2>
            </div>
            <div className="faq">
              {faq.map((i) => (
                <details key={i.q}>
                  <summary>{i.q}</summary>
                  <p>{i.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section id="demo" className="section demo">
          <div className="container demo-grid">
            <div>
              <h2>{form.title}</h2>
              <p className="lead">{form.lead}</p>
              <ul className="points">
                {form.points.map((p) => (
                  <li key={p}>{p}</li>
                ))}
              </ul>
            </div>
            <LeadForm />
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="container footer-inner">
          <span>© 2026 {brand.name}. {brand.region}.</span>
          <a href="/privacy-policy.html" target="_blank" rel="noopener">Политика конфиденциальности</a>
        </div>
      </footer>
      <StickyCta />
    </>
  );
}
