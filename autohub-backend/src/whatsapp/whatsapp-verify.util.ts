/** Legacy helper для /api/whatsapp/webhook (prefer MetaWhatsAppConfig). */
export function getWhatsAppVerifyToken(): string {
  return (
    process.env.META_WHATSAPP_VERIFY_TOKEN?.trim() ||
    process.env.WHATSAPP_VERIFY_TOKEN?.trim() ||
    process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN?.trim() ||
    ''
  );
}
