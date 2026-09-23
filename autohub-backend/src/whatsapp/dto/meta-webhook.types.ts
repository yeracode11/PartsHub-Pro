export interface MetaWebhookPayload {
  object?: string;
  entry?: MetaWebhookEntry[];
}

export interface MetaWebhookEntry {
  id?: string;
  changes?: MetaWebhookChange[];
}

export interface MetaWebhookChange {
  field?: string;
  value?: MetaWebhookChangeValue;
}

export interface MetaWebhookChangeValue {
  metadata?: {
    display_phone_number?: string;
    phone_number_id?: string;
  };
  contacts?: Array<{ profile?: { name?: string }; wa_id?: string }>;
  messages?: MetaInboundMessage[];
  statuses?: unknown[];
}

export interface MetaInboundMessage {
  from: string;
  id: string;
  timestamp?: string;
  type: string;
  text?: { body?: string };
}

export interface ParsedMetaInboundEvent {
  phoneNumberId: string;
  wabaId?: string;
  messageId: string;
  from: string;
  type: string;
  textBody?: string;
}
