import { EntityManager } from 'typeorm';

/** Следующий номер заказа организации. Один INSERT, без гонки. */
export async function nextOrderNumber(
  manager: EntityManager,
  organizationId: string,
  now = new Date(),
): Promise<string> {
  const year = now.getFullYear();
  const rows: Array<{ lastValue: number | string }> = await manager.query(
    `INSERT INTO order_number_counters ("organizationId", year, "lastValue")
     VALUES ($1, $2, 1)
     ON CONFLICT ("organizationId", year)
     DO UPDATE SET "lastValue" = order_number_counters."lastValue" + 1
     RETURNING "lastValue"`,
    [organizationId, year],
  );
  const value = Number(rows[0]?.lastValue);
  return `ORD-${year}-${String(value).padStart(3, '0')}`;
}
