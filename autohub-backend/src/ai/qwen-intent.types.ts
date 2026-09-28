export const QWEN_INTENTS = [
  'search_part',
  'check_stock',
  'check_price',
  'create_order',
  'order_status',
  'warranty',
  'greeting',
  'unknown',
] as const;

export type QwenIntent = (typeof QWEN_INTENTS)[number];

export const QWEN_LANGUAGES = ['ru', 'kk', 'mixed', 'unknown'] as const;

export type QwenLanguage = (typeof QWEN_LANGUAGES)[number];

export interface QwenIntentVehicle {
  brand: string | null;
  model: string | null;
  generation: string | null;
  year: number | null;
  engine: string | null;
  body: string | null;
}

export interface QwenIntentPart {
  name: string | null;
  position: string | null;
}

export interface QwenIntentOrder {
  number: string | null;
}

export interface QwenIntentResult {
  intent: QwenIntent;
  language: QwenLanguage;
  vehicle: QwenIntentVehicle;
  part: QwenIntentPart;
  order: QwenIntentOrder;
}
