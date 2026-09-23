import { parseMetaInboundEvents } from './meta-webhook.parser';

describe('parseMetaInboundEvents', () => {
  it('parses text message and phone_number_id', () => {
    const events = parseMetaInboundEvents({
      object: 'whatsapp_business_account',
      entry: [
        {
          id: '3483066548542535',
          changes: [
            {
              field: 'messages',
              value: {
                metadata: { phone_number_id: '1398564366663975' },
                messages: [
                  {
                    from: '77776442004',
                    id: 'wamid.test123',
                    type: 'text',
                    text: { body: 'камри 70 колодки' },
                  },
                ],
              },
            },
          ],
        },
      ],
    });

    expect(events).toHaveLength(1);
    expect(events[0].phoneNumberId).toBe('1398564366663975');
    expect(events[0].messageId).toBe('wamid.test123');
    expect(events[0].textBody).toBe('камри 70 колодки');
  });
});
