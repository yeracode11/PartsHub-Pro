const paths: Record<string, React.ReactNode> = {
  parts: (<><circle cx="12" cy="12" r="3.2" /><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1" /></>),
  wrench: (<path d="M14.7 6.3a4 4 0 0 0-5.4 5.1L3.5 17.2a1.8 1.8 0 0 0 2.6 2.6l5.8-5.8a4 4 0 0 0 5.1-5.4l-2.6 2.6-2.2-.4-.4-2.2 2.6-2.6z" />),
  box: (<><path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5z" /><path d="M3.5 7.5 12 12l8.5-4.5M12 12v9" /></>),
  offline: (<><path d="M3 9a14 14 0 0 1 18 0M6 12.5a9.5 9.5 0 0 1 12 0M9 16a5 5 0 0 1 6 0" /><circle cx="12" cy="19" r="0.6" /><path d="M4 4l16 16" /></>),
  roles: (<><circle cx="9" cy="8" r="3.2" /><path d="M3 19c.6-3.3 3-5 6-5s5.4 1.7 6 5" /><path d="M16 5.2a3 3 0 0 1 0 5.6M18 14.2c1.7.7 2.8 2.2 3.1 4.8" /></>),
  shield: (<><path d="M12 3 4.5 6v5.5c0 4.4 3 8 7.5 9.5 4.5-1.5 7.5-5.1 7.5-9.5V6z" /><path d="m9 12 2.2 2.2L15.5 10" /></>),
  chat: (<><path d="M4 5.5h16v10H9.5L5.5 19v-3.5H4z" /><path d="M8 9.5h8M8 12.5h5" /></>),
  check: <path d="m5 12.5 4.2 4.2L19 7" />,
};

export function Icon({ name, size = 24 }: { name: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {paths[name] ?? paths.box}
    </svg>
  );
}
