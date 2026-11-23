'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { Flag } from '@/components/Flag';
import { countries, type Country } from '@/lib/countries';

type Props = { value: Country; onChange: (c: Country) => void; labelledBy: string };

/** Выпадающий список стран с флагами: кнопка + listbox, управляется с клавиатуры. */
export function CountryPicker({ value, onChange, labelledBy }: Props) {
  const listId = useId();
  const root = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!root.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  const openList = () => {
    setActive(Math.max(0, countries.findIndex((c) => c.code === value.code)));
    setOpen(true);
  };
  const choose = (c: Country) => {
    onChange(c);
    setOpen(false);
    button.current?.focus();
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (!open) {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        openList();
      }
      return;
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((i) => (i + 1) % countries.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((i) => (i - 1 + countries.length) % countries.length);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      choose(countries[active]);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      setOpen(false);
      button.current?.focus();
    } else if (e.key === 'Tab') {
      setOpen(false);
    }
  };

  return (
    <div className="country" ref={root} onKeyDown={onKeyDown}>
      <button
        ref={button}
        type="button"
        className="country-btn"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={open ? listId : undefined}
        aria-label={`Страна: ${value.name}, +${value.dial}`}
        aria-describedby={labelledBy}
        onClick={() => (open ? setOpen(false) : openList())}
      >
        <Flag code={value.code} />
        <span className="country-dial">+{value.dial}</span>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="m3 4.5 3 3 3-3" />
        </svg>
      </button>
      {open && (
        <ul id={listId} className="country-list" role="listbox" aria-label="Страна">
          {countries.map((c, i) => (
            <li
              key={c.code}
              role="option"
              aria-selected={c.code === value.code}
              data-active={i === active}
              onMouseEnter={() => setActive(i)}
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => choose(c)}
            >
              <Flag code={c.code} />
              <span className="country-name">{c.name}</span>
              <span className="country-code">+{c.dial}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
