import axios from 'axios';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';
import { WhatsAppMetaRecipientCacheService } from './whatsapp-meta-recipient-cache.service';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('MetaWhatsAppService', () => {
  const config = {
    messagesUrl: (phoneNumberId: string) =>
      `https://graph.facebook.com/v26.0/${phoneNumberId}/messages`,
  } as MetaWhatsAppConfig;

  const recipientCache = {
    resolveGraphApiTo: jest.fn(),
    rememberFromMetaResponse: jest.fn(),
  } as unknown as WhatsAppMetaRecipientCacheService;

  let service: MetaWhatsAppService;

  beforeEach(() => {
    jest.clearAllMocks();
    (recipientCache.resolveGraphApiTo as jest.Mock).mockResolvedValue(null);
    service = new MetaWhatsAppService(config, recipientCache);
  });

  it('sendTextMessage posts wa_id digits when cache miss', async () => {
    mockedAxios.post.mockResolvedValue({
      data: {
        messages: [{ id: 'wamid.out' }],
        contacts: [{ input: '787776442004', wa_id: '77776442004' }],
      },
    });

    await service.sendTextMessage(
      '1398564366663975',
      '+7 777 644 2004',
      'test body',
      'meta-access-token-secret',
    );

    expect(mockedAxios.post).toHaveBeenCalledWith(
      'https://graph.facebook.com/v26.0/1398564366663975/messages',
      {
        messaging_product: 'whatsapp',
        to: '77776442004',
        type: 'text',
        text: { body: 'test body' },
      },
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer meta-access-token-secret',
          'Content-Type': 'application/json',
        }),
        timeout: 30_000,
      }),
    );

    expect(recipientCache.rememberFromMetaResponse).toHaveBeenCalledWith(
      '77776442004',
      '787776442004',
    );
  });

  it('uses cached Graph API input from Meta when present', async () => {
    (recipientCache.resolveGraphApiTo as jest.Mock).mockResolvedValue(
      '787776442004',
    );
    mockedAxios.post.mockResolvedValue({
      data: { messages: [{ id: 'wamid.out' }] },
    });

    await service.sendTextMessage(
      '1398564366663975',
      '77776442004',
      'echo',
      'token',
    );

    expect(mockedAxios.post).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ to: '787776442004' }),
      expect.any(Object),
    );
  });
});
