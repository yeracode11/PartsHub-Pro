// Конвертирует сырые скриншоты (PNG 1320x2868 с симулятора) в WebP для public/screens.
// Запуск: node scripts/optimize-screens.mjs <папка-с-png>
import { readdir, mkdir } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const src = process.argv[2];
if (!src) {
  console.error('Укажите папку с PNG: node scripts/optimize-screens.mjs <папка>');
  process.exit(1);
}
const out = path.join(import.meta.dirname, '..', 'public', 'screens');
await mkdir(out, { recursive: true });

for (const f of (await readdir(src)).filter((n) => n.endsWith('.png') && !n.endsWith('.s.png'))) {
  const name = f.replace(/\.png$/, '');
  await sharp(path.join(src, f))
    .resize({ width: 828 })
    .webp({ quality: 86 })
    .toFile(path.join(out, `${name}.webp`));
  console.log('ok', name);
}
