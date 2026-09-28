import axios from 'axios';
import { QwenService } from './qwen.service';
import { QwenConfig } from './qwen.config';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('QwenService', () => {
  const config = {
    apiBaseUrl: 'http://100.107.51.115:8000',
    timeoutMs: 10_000,
  } as QwenConfig;

  let service: QwenService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new QwenService(config);
  });

  const validBody = {
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
  };

  it('parseIntent returns check_stock for valid response', async () => {
    mockedAxios.post.mockResolvedValue({ status: 200, data: validBody });

    const result = await service.parseIntent(
      'камри 70 передние колодки есть?',
    );

    expect(mockedAxios.post).toHaveBeenCalledWith(
      'http://100.107.51.115:8000/v1/intent',
      { message: 'камри 70 передние колодки есть?', language: 'auto' },
      expect.objectContaining({ timeout: 10_000 }),
    );
    expect(result?.intent).toBe('check_stock');
    expect(result?.vehicle.model).toBe('Camry');
    expect(result?.part.name).toBe('brake_pad');
  });

  it('handles malformed JSON safely', async () => {
    mockedAxios.post.mockResolvedValue({ status: 200, data: 'not-json' });

    const result = await service.parseIntent('test');

    expect(result).toBeNull();
  });

  it('handles HTTP 500 safely', async () => {
    mockedAxios.post.mockResolvedValue({ status: 500, data: { error: 'fail' } });

    const result = await service.parseIntent('test');

    expect(result).toBeNull();
  });

  it('handles HTTP 4xx safely', async () => {
    mockedAxios.post.mockResolvedValue({ status: 422, data: {} });

    expect(await service.parseIntent('test')).toBeNull();
  });

  it('handles timeout safely', async () => {
    mockedAxios.post.mockRejectedValue({ code: 'ECONNABORTED', message: 'timeout' });

    expect(await service.parseIntent('test')).toBeNull();
  });

  it('handles connection refused safely', async () => {
    mockedAxios.post.mockRejectedValue({ code: 'ECONNREFUSED', message: 'refused' });

    expect(await service.parseIntent('test')).toBeNull();
  });

  it('coerces unknown intent from API', async () => {
    mockedAxios.post.mockResolvedValue({
      status: 200,
      data: {
        ...validBody,
        intent: 'not_a_real_intent',
      },
    });

    const result = await service.parseIntent('hello');

    expect(result?.intent).toBe('unknown');
  });

  it('returns null when response is not an object', async () => {
    mockedAxios.post.mockResolvedValue({ status: 200, data: null });

    expect(await service.parseIntent('x')).toBeNull();
  });

  it('returns null when QWEN_API_URL missing', async () => {
    const emptyConfig = { apiBaseUrl: '', timeoutMs: 10_000 } as QwenConfig;
    const local = new QwenService(emptyConfig);

    expect(await local.parseIntent('x')).toBeNull();
    expect(mockedAxios.post).not.toHaveBeenCalled();
  });
});
