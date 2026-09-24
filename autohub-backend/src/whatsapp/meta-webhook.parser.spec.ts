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
    expect(events[0].recipientWaId).toBe('77776442004');
  });

  it('returns empty for empty payload', () => {
    expect(parseMetaInboundEvents({})).toEqual([]);
    expect(parseMetaInboundEvents({ object: 'other' })).toEqual([]);
  });

  it('returns empty for status-only webhook', () => {
    const events = parseMetaInboundEvents({
      object: 'whatsapp_business_account',
      entry: [
        {
          changes: [
            {
              field: 'messages',
              value: {
                metadata: { phone_number_id: '1398564366663975' },
                statuses: [{ id: 'wamid.status', status: 'read' }],
              },
            },
          ],
        },
      ],
    });

    expect(events).toEqual([]);
  });
});
