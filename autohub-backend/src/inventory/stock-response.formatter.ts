import { QwenIntentResult, QwenLanguage } from '../ai/qwen-intent.types';
import { Item } from '../items/entities/item.entity';
import { foldText } from './part-search-keywords.util';

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
    steering_rack: 'рулевая рейка',
    engine: 'двигатель',
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

/** Код кузова/поколения в названии товара: E60, F10, W211, XV70. */
const CHASSIS_CODE = /\b(?:[efg]\d{2}|w\d{3}|xv\d{2})\b/g;

/** Уникальные коды кузова из названий найденных товаров, в порядке появления. */
export function chassisCodes(items: Item[]): string[] {
  const codes: string[] = [];
  for (const item of items) {
    const text = foldText(`${item.name} ${item.description ?? ''}`);
    for (const match of text.match(CHASSIS_CODE) ?? []) {
      const code = match.toUpperCase();
      if (!codes.includes(code)) codes.push(code);
    }
  }
  return codes;
}

export function formatStockNotFound(intent: QwenIntentResult): string {
  const lang = pickLanguage(intent.language);
  const vehicle = vehicleLabel(intent);
  const part = lang === 'kk' ? partLabelKk(intent) : partLabelRu(intent);
  const target = vehicle ? `${vehicle}: ${part}` : part;

  if (lang === 'kk') {
    return `${target} қазір қолда табылмады. Автокөлік моделін, жылын немесе VIN жазсаңыз, менеджер қолмен тексеріп береді.`;
  }
  return `${target}: в наличии сейчас не нашли. Напишите модель, год или VIN, и менеджер проверит вручную.`;
}

export function formatNeedPart(intent: QwenIntentResult): string {
  const vehicle = vehicleLabel(intent);
  if (pickLanguage(intent.language) === 'kk') {
    return vehicle
      ? `${vehicle} үшін қай бөлшек керек? Атауын жазыңыз.`
      : 'Қай бөлшек керек? Атауын және көлік маркасын жазыңыз.';
  }
  return vehicle
    ? `Какая деталь нужна для ${vehicle}? Напишите название.`
    : 'Какая деталь нужна? Напишите название и марку автомобиля.';
}

export function formatGreeting(language: QwenLanguage): string {
  return pickLanguage(language) === 'kk'
    ? 'Сәлеметсіз бе! Қай бөлшек керек? Көлік маркасын және бөлшек атауын жазыңыз.'
    : 'Здравствуйте! Какая деталь нужна? Напишите марку автомобиля и название детали.';
}

/** Вопросы, на которые бот сам не отвечает (заказ, гарантия, происхождение двигателя). */
export function formatHandoff(language: QwenLanguage): string {
  return pickLanguage(language) === 'kk'
    ? 'Сұрағыңызды қабылдадық, менеджер жақын арада жауап береді.'
    : 'Ваш вопрос принят, менеджер ответит в ближайшее время.';
}

/** Парсер недоступен или вернул мусор: не гадаем, передаём менеджеру. */
export function formatParserUnavailable(messageText: string): string {
  return formatHandoff(/[әіңғүұқөһ]/i.test(messageText) ? 'kk' : 'ru');
}

/** 90000 → «90 000»: цена читается как в разговоре. */
function formatPrice(value: number): string {
  return String(Math.round(value)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

/**
 * Ответ клиенту, который нашли товар. Говорим как продавец: что есть, сколько
 * стоит, что уточнить и что делать дальше. Остаток на складе не раскрываем.
 */
export function formatStockFound(
  intent: QwenIntentResult,
  items: Item[],
): string {
  const lang = pickLanguage(intent.language);
  const vehicle = vehicleLabel(intent);
  const part = lang === 'kk' ? partLabelKk(intent) : partLabelRu(intent);
  const primary = items[0];
  const price = Number(primary.price);
  const hasPrice = Number.isFinite(price) && price > 0;
  const priceQuestion = intent.intent === 'check_price';
  const more = items.length > 1;

  const opening =
    lang === 'kk'
      ? `${priceQuestion ? 'Бағасын айтамыз' : 'Иә, бар'}: ${vehicle ? `${vehicle} үшін ` : ''}${part}.`
      : `${priceQuestion ? 'Подскажу по цене' : 'Да, есть'}: ${part}${vehicle ? ` на ${vehicle}` : ''}.`;

  const offer = hasPrice
    ? `${primary.name} — ${formatPrice(price)} ₸.`
    : `${primary.name}.`;

  const lines = [opening, offer];

  if (more) {
    lines.push(
      lang === 'kk'
        ? 'Басқа нұсқалар да бар, қаласаңыз айтамыз.'
        : 'Есть и другие варианты, расскажу, если нужно.',
    );
  }

  const clarify = generationQuestion(intent, items);
  if (clarify) lines.push(clarify);

  lines.push(
    lang === 'kk'
      ? 'Ұнаса, жазыңыз — рәсімдеп береміз.'
      : 'Если подходит, напишите — оформим.',
  );

  return lines.join('\n');
}

/**
 * Клиент не назвал модель/поколение, а в найденных товарах оно есть:
 * совместимость не утверждаем, а уточняем («У вас E60?»).
 */
function generationQuestion(
  intent: QwenIntentResult,
  items: Item[],
): string | null {
  if (intent.vehicle.generation || intent.vehicle.model) return null;
  const codes = chassisCodes(items);
  if (codes.length === 0) return null;
  const list = codes.join(' или ');
  return pickLanguage(intent.language) === 'kk'
    ? `Сізде ${list} ме? Айтсаңыз, сәйкестігін нақтылаймыз.`
    : `У вас ${list}? Скажите, и я уточню, подойдёт ли именно к вашей машине.`;
}
