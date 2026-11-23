'use client';

import { useId, useState } from 'react';
import { CountryPicker } from '@/components/CountryPicker';
import { form } from '@/content/site';
import { defaultCountry, formatNational, maxDigits, normalizeNational, type Country } from '@/lib/countries';

type Errors = Partial<Record<'name' | 'phone' | 'city', string>>;
type Status = 'idle' | 'sending' | 'ok' | 'error';

export function LeadForm() {
  const uid = useId();
  const [country, setCountry] = useState<Country>(defaultCountry);
  const [phone, setPhone] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [status, setStatus] = useState<Status>('idle');

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const name = String(fd.get('name') ?? '').trim();
    const city = String(fd.get('city') ?? '').trim();
    const digits = phone;

    const next: Errors = {};
    if (name.length < 2) next.name = 'Укажите имя';
    if (digits.length !== maxDigits(country)) next.phone = `Введите номер полностью: ${maxDigits(country)} цифр после +${country.dial}`;
    if (city.length < 2) next.city = 'Укажите город';
    setErrors(next);
    if (Object.keys(next).length) return;

    setStatus('sending');
    try {
      const res = await fetch('/api/lead', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          name,
          phone: digits,
          country: country.code,
          city,
          businessType: fd.get('businessType'),
          comment: fd.get('comment'),
          website: fd.get('website'),
        }),
      });
      if (!res.ok) throw new Error(String(res.status));
      setStatus('ok');
    } catch {
      setStatus('error');
    }
  }

  if (status === 'ok') {
    return (
      <div className="form" role="status">
        <p className="form-status ok">{form.success}</p>
      </div>
    );
  }

  const id = (k: string) => `${uid}-${k}`;

  return (
    <form className="form" onSubmit={onSubmit} noValidate>
      <div className="field">
        <label htmlFor={id('name')}>Имя</label>
        <input
          id={id('name')} name="name" className="input" autoComplete="name"
          aria-invalid={!!errors.name} aria-describedby={errors.name ? id('name-err') : undefined}
        />
        {errors.name && <span id={id('name-err')} className="field-error">{errors.name}</span>}
      </div>

      <div className="field">
        <label id={id('phone-label')} htmlFor={id('phone')}>Телефон (WhatsApp)</label>
        <div className="phone-row">
          <CountryPicker
            value={country}
            labelledBy={id('phone-label')}
            onChange={(c) => {
              setCountry(c);
              setPhone((p) => p.slice(0, maxDigits(c)));
            }}
          />
          <input
            id={id('phone')} name="phone" className="input" type="tel" inputMode="tel" autoComplete="tel-national"
            placeholder={country.placeholder} value={formatNational(phone, country)}
            onChange={(e) => setPhone(normalizeNational(e.target.value, country))}
            aria-invalid={!!errors.phone} aria-describedby={errors.phone ? id('phone-err') : undefined}
          />
        </div>
        {errors.phone && <span id={id('phone-err')} className="field-error">{errors.phone}</span>}
      </div>

      <div className="field">
        <label htmlFor={id('city')}>Город</label>
        <input
          id={id('city')} name="city" className="input" autoComplete="address-level2"
          aria-invalid={!!errors.city} aria-describedby={errors.city ? id('city-err') : undefined}
        />
        {errors.city && <span id={id('city-err')} className="field-error">{errors.city}</span>}
      </div>

      <div className="field">
        <label htmlFor={id('type')}>Тип бизнеса</label>
        <select id={id('type')} name="businessType" className="input" defaultValue="dismantler">
          {form.businessTypes.map((t) => (
            <option key={t.value} value={t.value}>{t.label}</option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor={id('comment')}>Комментарий <small>(необязательно)</small></label>
        <textarea id={id('comment')} name="comment" className="input" rows={3} maxLength={1000} />
      </div>

      <div className="hp" aria-hidden="true">
        <label>Сайт<input name="website" tabIndex={-1} autoComplete="off" /></label>
      </div>

      {status === 'error' && <p className="form-status err" role="alert">{form.error}</p>}

      <button type="submit" className="btn btn-primary" disabled={status === 'sending'}>
        {status === 'sending' ? 'Отправляем…' : form.submit}
      </button>
      <p className="consent">
        Отправляя заявку, вы соглашаетесь на обработку персональных данных в соответствии с{' '}
        <a href="/privacy-policy.html" target="_blank" rel="noopener">политикой конфиденциальности</a>.
      </p>
    </form>
  );
}
