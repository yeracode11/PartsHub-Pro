import { QwenIntentResult, QwenLanguage } from '../ai/qwen-intent.types';
import { Item } from '../items/entities/item.entity';
import { partKeywords } from './part-search-keywords.util';

function vehicleLabel(intent: QwenIntentResult): string {
  return [
    intent.vehicle.brand,
    intent.vehicle.model,
    intent.vehicle.generation,
  ]
    .filter(Boolean)
    .join(' ');
}

function partLabelRu(intent: QwenIntentResult): string {
  const position =
    intent.part.position === 'front'
      ? 'передние '
      : intent.part.position === 'rear'
        ? 'задние '
        : '';

  const name = intent.part.name?.toLowerCase() ?? '';
  const ruMap: Record<string, string> = {
    brake_pad: 'тормозные колодки',
    brake_disc: 'тормозные диски',
    oil_filter: 'масляный фильтр',
    air_filter: 'воздушный фильтр',
    cabin_filter: 'салонный фильтр',
    spark_plug: 'свечи зажигания',
    battery: 'аккумулятор',
    radiator: 'радиатор',
    alternator: 'генератор',
    starter: 'стартер',
    automatic_transmission: 'АКПП',
    manual_transmission: 'МКПП',
  };

  const partRu = ruMap[name] ?? name.replace(/_/g, ' ');
  return `${position}${partRu}`.trim();
}

function partLabelKk(intent: QwenIntentResult): string {
  const position =
    intent.part.position === 'front'
      ? 'алдыңғы '
      : intent.part.position === 'rear'
        ? 'артқы '
        : '';
  const name = intent.part.name?.toLowerCase() ?? '';
  const kkMap: Record<string, string> = {
    brake_pad: 'тежегіш колодкалары',
    brake_disc: 'тежегіш дискілері',
    oil_filter: 'май сүзгісі',
  };
  const partKk = kkMap[name] ?? partLabelRu(intent);
  return `${position}${partKk}`.trim();
}

function pickLanguage(language: QwenLanguage): 'ru' | 'kk' {
  return language === 'kk' ? 'kk' : 'ru';
}

function formatQuantity(qty: number, lang: 'ru' | 'kk'): string {
  if (lang === 'kk') {
    return `Қолда бар: ${qty} дана.`;
  }
  const mod10 = qty % 10;
  const mod100 = qty % 100;
  let word = 'комплектов';
  if (mod100 < 11 || mod100 > 14) {
    if (mod10 === 1) word = 'комплект';
    else if (mod10 >= 2 && mod10 <= 4) word = 'комплекта';
  }
  return `В наличии: ${qty} ${word}.`;
}

function extractBrandFromItemName(name: string): string | null {
  const trimmed = name.trim();
  if (!trimmed) return null;
  return trimmed.split(/\s+/)[0] ?? null;
}

export function formatStockNotFound(intent: QwenIntentResult): string {
  const lang = pickLanguage(intent.language);
  const vehicle = vehicleLabel(intent) || '—';
  const part =
    lang === 'kk' ? partLabelKk(intent) : partLabelRu(intent);

  if (lang === 'kk') {
    return `${vehicle} үшін ${part} қазір табылмады.`;
  }
  return `По ${vehicle} ${part} сейчас не найдены.`;
}

export function formatStockFound(
  intent: QwenIntentResult,
  items: Item[],
): string {
  const lang = pickLanguage(intent.language);
  const vehicle = vehicleLabel(intent);
  const part =
    lang === 'kk' ? partLabelKk(intent) : partLabelRu(intent);

  const lines: string[] = [];
  if (lang === 'kk') {
    lines.push('Иә, таптық:');
  } else {
    lines.push('Да, нашли:');
  }

  if (vehicle) {
    lines.push(vehicle);
  }
  lines.push(part);

  const primary = items[0];
  const brandLine =
    extractBrandFromItemName(primary.name) ??
    (partKeywords(intent.part.name)[0] ?? primary.name);

  if (primary.name && !lines.includes(primary.name)) {
    lines.push(primary.name);
  } else if (brandLine) {
    lines.push(brandLine);
  }

  lines.push(formatQuantity(primary.quantity, lang));

  const price = Number(primary.price);
  if (Number.isFinite(price) && price > 0) {
    if (lang === 'kk') {
      lines.push(`Бағасы: ${price} ₸.`);
    } else {
      lines.push(`Цена: ${price} ₸.`);
    }
  }

  if (items.length > 1) {
    if (lang === 'kk') {
      lines.push(`Басқа нұсқалар: ${items.length - 1}.`);
    } else {
      lines.push(`Ещё вариантов: ${items.length - 1}.`);
    }
  }

  return lines.join('\n');
}
