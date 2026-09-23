import {
  MetaWebhookPayload,
  ParsedMetaInboundEvent,
} from './dto/meta-webhook.types';

export function parseMetaInboundEvents(
  body: MetaWebhookPayload,
): ParsedMetaInboundEvent[] {
  const events: ParsedMetaInboundEvent[] = [];

  if (body.object !== 'whatsapp_business_account' || !body.entry?.length) {
    return events;
  }

  for (const entry of body.entry) {
    const wabaId = entry.id;
    for (const change of entry.changes ?? []) {
      if (change.field !== 'messages') continue;

      const value = change.value;
      const phoneNumberId = value?.metadata?.phone_number_id;
      if (!phoneNumberId) continue;

      for (const msg of value?.messages ?? []) {
        if (!msg.id || !msg.from) continue;

        events.push({
          phoneNumberId,
          wabaId,
          messageId: msg.id,
          from: msg.from,
          type: msg.type,
          textBody: msg.type === 'text' ? msg.text?.body : undefined,
        });
      }
    }
  }

  return events;
}
