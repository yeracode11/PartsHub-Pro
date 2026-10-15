'use client';

import { useEffect, useState } from 'react';

/** Кнопка внизу экрана на телефоне: появляется после первого экрана и прячется у формы. */
export function StickyCta() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    const form = document.getElementById('demo');
    const update = () => {
      const pastHero = window.scrollY > window.innerHeight * 0.7;
      const formTop = form?.getBoundingClientRect().top ?? Infinity;
      setShow(pastHero && formTop > window.innerHeight * 0.6);
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, []);

  return (
    <div className="sticky-cta" data-show={show} aria-hidden={!show}>
      <a href="#demo" className="btn btn-primary" tabIndex={show ? 0 : -1}>Запросить демо</a>
    </div>
  );
}
