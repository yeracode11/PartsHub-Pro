import { META_WEBHOOK_VERIFY_ENV_KEY } from './meta-whatsapp.config';

/** Legacy helper для /api/whatsapp/webhook — тот же канонический env. */
export function getWhatsAppVerifyToken(): string {
  return process.env[META_WEBHOOK_VERIFY_ENV_KEY]?.trim() || '';
}
