'use client';

import Image from 'next/image';
import { useRef, useState } from 'react';

type Shot = { id: string; label: string; name: string; alt: string; caption: string };

/** Десктопные кадры приложения: один на экране, переключение вкладками. Файлы — public/screens/desktop-<name>.webp. */
export function DesktopTabs({ shots }: { shots: Shot[] }) {
  const [active, setActive] = useState(0);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);

  const onKeyDown = (e: React.KeyboardEvent, i: number) => {
    const last = shots.length - 1;
    const next = e.key === 'ArrowRight' ? (i === last ? 0 : i + 1) : e.key === 'ArrowLeft' ? (i === 0 ? last : i - 1) : null;
    if (next === null) return;
    e.preventDefault();
    setActive(next);
    tabs.current[next]?.focus();
  };

  const shot = shots[active];
  return (
    <div className="dtabs">
      <div className="dtabs-list" role="tablist" aria-label="Разделы приложения на компьютере">
        {shots.map((s, i) => (
          <button
            key={s.id}
            ref={(el) => { tabs.current[i] = el; }}
            id={`dtab-${s.id}`}
            type="button"
            role="tab"
            aria-selected={i === active}
            aria-controls="dtab-panel"
            tabIndex={i === active ? 0 : -1}
            onClick={() => setActive(i)}
            onKeyDown={(e) => onKeyDown(e, i)}
          >
            {s.label}
          </button>
        ))}
      </div>
      <figure id="dtab-panel" role="tabpanel" aria-labelledby={`dtab-${shot.id}`} className="desktop-shot">
        <div className="desktop-win">
          <Image
            key={shot.name}
            src={`/screens/desktop-${shot.name}.webp`}
            alt={shot.alt}
            width={1800}
            height={981}
            sizes="(max-width: 1232px) 100vw, 1200px"
          />
        </div>
        <figcaption>{shot.caption}</figcaption>
      </figure>
    </div>
  );
}
