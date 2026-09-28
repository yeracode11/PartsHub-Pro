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
};

export const FRONT_POSITION_TERMS = ['передн', 'front', 'перед'];
export const REAR_POSITION_TERMS = ['задн', 'rear', 'зад'];

export function partKeywords(partName: string | null): string[] {
  if (!partName?.trim()) return [];
  const key = partName.trim().toLowerCase();
  return QWEN_PART_SEARCH_KEYWORDS[key] ?? [key.replace(/_/g, ' '), key];
}

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
  const vehicleTerms = vehicleSearchTerms(vehicle);
  const partTerms = partKeywords(part.name);

  for (const term of vehicleTerms) {
    if (!text.includes(term)) {
      return false;
    }
  }

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
