import axios from 'axios';
import { MetaWhatsAppService } from './meta-whatsapp.service';
import { MetaWhatsAppConfig } from './meta-whatsapp.config';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('MetaWhatsAppService', () => {
  const config = {
    messagesUrl: (phoneNumberId: string) =>
      `https://graph.facebook.com/v26.0/${phoneNumberId}/messages`,
  } as MetaWhatsAppConfig;

  let service: MetaWhatsAppService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new MetaWhatsAppService(config);
  });

  it('sendTextMessage posts to Graph API with bearer token', async () => {
    mockedAxios.post.mockResolvedValue({
      data: { messages: [{ id: 'wamid.out' }] },
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
  });
});
