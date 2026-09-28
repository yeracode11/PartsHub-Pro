import 'reflect-metadata';
import { parseQwenIntentResponse } from './qwen-intent.validator';

describe('parseQwenIntentResponse', () => {
  it('parses check_stock payload', () => {
    const result = parseQwenIntentResponse({
      intent: 'check_stock',
      language: 'ru',
      vehicle: {
        brand: 'Toyota',
        model: 'Camry',
        generation: '70',
        year: null,
        engine: null,
        body: null,
      },
      part: { name: 'brake_pad', position: 'front' },
      order: { number: null },
    });

    expect(result?.intent).toBe('check_stock');
    expect(result?.language).toBe('ru');
  });

  it('returns null for non-object', () => {
    expect(parseQwenIntentResponse('bad')).toBeNull();
  });
});
