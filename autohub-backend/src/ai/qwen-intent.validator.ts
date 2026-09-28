import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { QwenIntentResponseDto } from './dto/qwen-intent-response.dto';
import {
  QwenIntent,
  QwenIntentResult,
  QWEN_INTENTS,
  QWEN_LANGUAGES,
  QwenLanguage,
} from './qwen-intent.types';

function nullIfEmpty(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const s = String(value).trim();
  return s.length ? s : null;
}

function nullNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function coerceIntent(raw: unknown): QwenIntent {
  if (typeof raw === 'string' && (QWEN_INTENTS as readonly string[]).includes(raw)) {
    return raw as QwenIntent;
  }
  return 'unknown';
}

function coerceLanguage(raw: unknown): QwenLanguage {
  if (typeof raw === 'string' && (QWEN_LANGUAGES as readonly string[]).includes(raw)) {
    return raw as QwenLanguage;
  }
  return 'unknown';
}

const EMPTY_VEHICLE = {
  brand: null,
  model: null,
  generation: null,
  year: null,
  engine: null,
  body: null,
};

const EMPTY_PART = { name: null, position: null };
const EMPTY_ORDER = { number: null };

/**
 * Runtime validation ответа Qwen `/v1/intent`.
 * При частично валидных данных — unknown intent + безопасные null-поля.
 */
export function parseQwenIntentResponse(raw: unknown): QwenIntentResult | null {
  if (raw === null || typeof raw !== 'object') {
    return null;
  }

  const dto = plainToInstance(QwenIntentResponseDto, raw);
  const errors = validateSync(dto, {
    whitelist: true,
    forbidNonWhitelisted: false,
  });

  const body = raw as Record<string, unknown>;
  const vehicleRaw =
    body.vehicle && typeof body.vehicle === 'object'
      ? (body.vehicle as Record<string, unknown>)
      : {};
  const partRaw =
    body.part && typeof body.part === 'object'
      ? (body.part as Record<string, unknown>)
      : {};
  const orderRaw =
    body.order && typeof body.order === 'object'
      ? (body.order as Record<string, unknown>)
      : {};

  const result: QwenIntentResult = {
    intent: errors.length ? coerceIntent(body.intent) : coerceIntent(dto.intent),
    language: errors.length
      ? coerceLanguage(body.language)
      : coerceLanguage(dto.language),
    vehicle: {
      brand: nullIfEmpty(vehicleRaw.brand),
      model: nullIfEmpty(vehicleRaw.model),
      generation: nullIfEmpty(vehicleRaw.generation),
      year: nullNumber(vehicleRaw.year),
      engine: nullIfEmpty(vehicleRaw.engine),
      body: nullIfEmpty(vehicleRaw.body),
    },
    part: {
      name: nullIfEmpty(partRaw.name),
      position: nullIfEmpty(partRaw.position),
    },
    order: {
      number: nullIfEmpty(orderRaw.number),
    },
  };

  if (typeof body.intent !== 'string') {
    result.intent = 'unknown';
  }

  if (errors.length && result.intent === 'unknown') {
    return result;
  }

  if (errors.length) {
    return result;
  }

  return result;
}

export function emptyQwenIntentUnknown(): QwenIntentResult {
  return {
    intent: 'unknown',
    language: 'unknown',
    vehicle: { ...EMPTY_VEHICLE },
    part: { ...EMPTY_PART },
    order: { ...EMPTY_ORDER },
  };
}
