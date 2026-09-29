import { QwenIntentPart, QwenIntentVehicle } from '../ai/qwen-intent.types';

/** Qwen canonical part name → поисковые фрагменты в name/description (RU + EN). */
export const QWEN_PART_SEARCH_KEYWORDS: Record<string, string[]> = {
  brake_pad: ['колодк', 'brake pad', 'brake_pad'],
  brake_disc: ['диск', 'brake disc', 'brake_disc', 'тормозн'],
  oil_filter: ['масл', 'oil filter', 'oil_filter', 'фильтр масл'],
  air_filter: ['воздуш', 'air filter', 'air_filter'],
  cabin_filter: ['салон', 'cabin filter', 'cabin_filter'],
  spark_plug: ['свеч', 'spark plug', 'spark_plug'],
  battery: ['аккумулятор', 'battery', 'акб'],
  radiator: ['радиатор', 'radiator'],
  alternator: ['генератор', 'alternator'],
  starter: ['стартер', 'starter'],
  automatic_transmission: ['акпп', 'automatic', 'automatic_transmission'],
  manual_transmission: ['мкпп', 'manual', 'manual_transmission'],
  steering_rack: [
    'рулевая рейка',
    'рулевую рейку',
    'рулевой рейка',
    'рулеваярейка',
    'steering rack',
    'steering_rack',
  ],
  engine: ['двигател', 'мотор', 'engine', 'двс'],
};

export const FRONT_POSITION_TERMS = ['передн', 'front', 'перед'];
export const REAR_POSITION_TERMS = ['задн', 'rear', 'зад'];

export function partKeywords(partName: string | null): string[] {
  if (!partName?.trim()) return [];
  const key = partName.trim().toLowerCase();
  return QWEN_PART_SEARCH_KEYWORDS[key] ?? [key.replace(/_/g, ' '), key];
}

/**
 * Terms for logging / soft hints. Matching uses matchesVehicle() —
 * model is not AND-required when generation is present (BMW "5 Series" + E60).
 */
export function vehicleSearchTerms(vehicle: QwenIntentVehicle): string[] {
  const terms: string[] = [];
  if (vehicle.brand?.trim()) {
    terms.push(vehicle.brand.trim().toLowerCase());
  }
  if (vehicle.model?.trim()) {
    terms.push(vehicle.model.trim().toLowerCase());
  }
  if (vehicle.generation?.trim()) {
    const gen = vehicle.generation.trim().toLowerCase();
    terms.push(gen);
    const digits = gen.replace(/\D/g, '');
    if (digits.length >= 2 && digits !== gen) {
      terms.push(digits);
    }
  }
  if (vehicle.year != null) {
    terms.push(String(vehicle.year));
  }
  if (vehicle.engine?.trim()) {
    terms.push(vehicle.engine.trim().toLowerCase());
  }
  if (vehicle.body?.trim()) {
    terms.push(vehicle.body.trim().toLowerCase());
  }
  return terms;
}

export function itemSearchText(name: string, description: string | null): string {
  return `${name} ${description ?? ''}`.toLowerCase();
}

export function containsAny(haystack: string, needles: string[]): boolean {
  return needles.some((n) => n.length > 0 && haystack.includes(n.toLowerCase()));
}

export function matchesPosition(
  haystack: string,
  position: string | null | undefined,
): boolean {
  if (!position?.trim()) {
    return true;
  }
  const pos = position.trim().toLowerCase();
  const hasFront = containsAny(haystack, FRONT_POSITION_TERMS);
  const hasRear = containsAny(haystack, REAR_POSITION_TERMS);

  if (pos === 'front') {
    if (hasRear && !hasFront) return false;
    return hasFront;
  }
  if (pos === 'rear') {
    if (hasFront && !hasRear) return false;
    return hasRear;
  }
  return true;
}

/** Engine / chassis codes as whole tokens: M113 ≠ M112, M113 ≠ M272. */
export function matchesEngineCode(haystack: string, engine: string): boolean {
  const code = engine.trim().toLowerCase();
  if (!code) return true;
  const escaped = code.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`(^|[^a-z0-9а-яё])${escaped}([^a-z0-9а-яё]|$)`, 'i');
  return re.test(haystack);
}

function matchesGeneration(haystack: string, generation: string): boolean {
  const gen = generation.trim().toLowerCase();
  if (!gen) return true;
  if (haystack.includes(gen)) return true;
  // Chassis like E60 / W211: also accept digit core only when full code absent
  // but prefer not to match bare short digits alone for 2-char codes in isolation —
  // keep digits as OR only when gen itself is alphanumeric (E60 → 60 weak), skip.
  return false;
}

/**
 * Vehicle match against item name/description.
 * - null fields are ignored
 * - brand required if set
 * - generation required if set (stronger than model for chassis codes)
 * - model required only when generation is absent
 * - engine matched as token (not naive substring across codes)
 */
export function matchesVehicle(
  haystack: string,
  vehicle: QwenIntentVehicle,
): boolean {
  if (vehicle.brand?.trim()) {
    if (!haystack.includes(vehicle.brand.trim().toLowerCase())) {
      return false;
    }
  }

  const generation = vehicle.generation?.trim() ?? '';
  const model = vehicle.model?.trim() ?? '';

  if (generation) {
    if (!matchesGeneration(haystack, generation)) {
      return false;
    }
    // model is optional when generation already matched (e.g. BMW "5 Series" + E60
    // vs product "рулевая рейка BMW E60")
  } else if (model) {
    if (!haystack.includes(model.toLowerCase())) {
      return false;
    }
  }

  if (vehicle.year != null) {
    if (!haystack.includes(String(vehicle.year))) {
      return false;
    }
  }

  if (vehicle.engine?.trim()) {
    if (!matchesEngineCode(haystack, vehicle.engine)) {
      return false;
    }
  }

  if (vehicle.body?.trim()) {
    if (!haystack.includes(vehicle.body.trim().toLowerCase())) {
      return false;
    }
  }

  return true;
}

export function itemMatchesStockIntent(
  name: string,
  description: string | null,
  quantity: number,
  vehicle: QwenIntentVehicle,
  part: QwenIntentPart,
  requireInStock: boolean,
): boolean {
  if (requireInStock && quantity <= 0) {
    return false;
  }

  const text = itemSearchText(name, description);

  if (!matchesVehicle(text, vehicle)) {
    return false;
  }

  const partTerms = partKeywords(part.name);
  if (partTerms.length > 0) {
    if (!containsAny(text, partTerms)) {
      return false;
    }
  }

  if (!matchesPosition(text, part.position)) {
    return false;
  }

  return true;
}
