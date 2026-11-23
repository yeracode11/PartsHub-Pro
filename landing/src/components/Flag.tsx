/** Упрощённые флаги стран СНГ (SVG 24×16), чтобы не зависеть от эмодзи: на Windows они не отображаются. */
const flags: Record<string, React.ReactNode> = {
  KZ: (<><rect width="24" height="16" fill="#00AFCA" /><circle cx="12" cy="7" r="3" fill="#FEC50C" /><rect x="5" y="12" width="14" height="1.2" fill="#FEC50C" /></>),
  RU: (<><rect width="24" height="16" fill="#fff" /><rect y="5.33" width="24" height="5.34" fill="#0039A6" /><rect y="10.67" width="24" height="5.33" fill="#D52B1E" /></>),
  BY: (<><rect width="24" height="16" fill="#4AA657" /><rect width="24" height="10.67" fill="#C8313E" /><rect width="3" height="16" fill="#fff" /><rect x="0.6" y="1" width="1.8" height="14" fill="#C8313E" opacity=".75" /></>),
  UZ: (<><rect width="24" height="16" fill="#1EB53A" /><rect width="24" height="5.1" fill="#0099B5" /><rect y="5.1" width="24" height="5.8" fill="#fff" /><rect y="5.1" width="24" height="0.5" fill="#CE1126" /><rect y="10.4" width="24" height="0.5" fill="#CE1126" /></>),
  KG: (<><rect width="24" height="16" fill="#E8112D" /><circle cx="12" cy="8" r="4.2" fill="#FFEF00" /><circle cx="12" cy="8" r="2.6" fill="#E8112D" /></>),
  TJ: (<><rect width="24" height="16" fill="#fff" /><rect width="24" height="4.57" fill="#CC0000" /><rect y="11.43" width="24" height="4.57" fill="#006600" /><circle cx="12" cy="8" r="1.4" fill="#F8C300" /></>),
  TM: (<><rect width="24" height="16" fill="#00843D" /><rect x="3" width="3.4" height="16" fill="#D22630" /><rect x="3.8" width="1.8" height="16" fill="#F2A900" opacity=".5" /></>),
  AZ: (<><rect width="24" height="16" fill="#509E2F" /><rect width="24" height="5.33" fill="#00B5E2" /><rect y="5.33" width="24" height="5.34" fill="#EF3340" /><circle cx="11" cy="8" r="2" fill="#fff" /><circle cx="11.7" cy="8" r="1.6" fill="#EF3340" /></>),
  AM: (<><rect width="24" height="16" fill="#0033A0" /><rect width="24" height="5.33" fill="#D90012" /><rect y="10.67" width="24" height="5.33" fill="#F2A800" /></>),
  MD: (<><rect width="24" height="16" fill="#FFD200" /><rect width="8" height="16" fill="#0046AE" /><rect x="16" width="8" height="16" fill="#CC092F" /></>),
};

export function Flag({ code }: { code: string }) {
  return (
    <svg className="flag" width="24" height="16" viewBox="0 0 24 16" aria-hidden="true" focusable="false">
      {flags[code] ?? <rect width="24" height="16" fill="#e5e7eb" />}
    </svg>
  );
}
