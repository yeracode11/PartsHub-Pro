import { Header } from '@/components/Header';
import { Icon } from '@/components/Icon';
import { LeadForm } from '@/components/LeadForm';
import Image from 'next/image';
import { PhoneFrame } from '@/components/PhoneFrame';
import { StickyCta } from '@/components/StickyCta';
import { siteUrl } from '@/lib/site-url';
import { audience, brand, extras, faq, features, form, hero, steps } from '@/content/site';

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
                <article key={i.title} className="card">
                  <span className="icon-tile"><Icon name={i.icon} /></span>
                  <h3>{i.title}</h3>
                  <p>{i.text}</p>
                </article>
              ))}
            </div>
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
            {f.desktop && (
              <figure className="container desktop-shot">
                <div className="desktop-win">
                  <Image
                    src={`/screens/desktop-${f.desktop.name}.webp`}
                    alt={f.desktop.alt}
                    width={1800}
                    height={981}
                    sizes="(max-width: 1232px) 100vw, 1200px"
                  />
                </div>
                <figcaption>{f.desktop.caption}</figcaption>
              </figure>
            )}
          </section>
        ))}

        <section className="section">
          <div className="container">
            <div className="section-head">
              <h2>{extras.title}</h2>
            </div>
            <div className="cards-4">
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
