export interface DonorEconomicsInput {
  purchasePrice: number;
  extraCosts: number;
  scrapIncome: number;
  /** Выручка по завершённым или оплаченным заказам. */
  soldRevenue: number;
  /** Сумма деталей в открытых заказах (резерв, в работе). */
  pendingRevenue: number;
  /** Остатки на складе по текущей цене продажи. */
  stockValue: number;
  partsCount: number;
  unitsInStock: number;
  unitsSold: number;
}

export interface DonorEconomics extends DonorEconomicsInput {
  totalCost: number;
  income: number;
  profit: number;
  /** Сколько процентов вложений уже вернулось; null, если вложений нет. */
  paybackPercent: number | null;
  isPaidBack: boolean;
  /** Прибыль, если продать всё, что лежит на складе и в заказах, по текущим ценам. */
  forecastProfit: number;
}

const round = (value: number) => Math.round(value * 100) / 100;

export interface DonorPartCostInput {
  id: number;
  price: number;
  /** Сколько штук снято с машины: остаток + проданные + в открытых заказах. */
  units: number;
}

/**
 * Делит вложения в машину между деталями пропорционально их цене продажи.
 * Себестоимость штуки — минимальная цена, ниже которой деталь продаётся в убыток.
 * Если цены не заданы, вложения делятся поровну на все снятые штуки.
 */
export function allocateDonorCost(
  totalCost: number,
  parts: DonorPartCostInput[],
): Map<number, number> {
  const totalValue = parts.reduce((sum, p) => sum + p.price * p.units, 0);
  const totalUnits = parts.reduce((sum, p) => sum + p.units, 0);

  return new Map(
    parts.map((part) => {
      let unitCost = 0;
      if (totalValue > 0) {
        unitCost = (totalCost * part.price) / totalValue;
      } else if (totalUnits > 0) {
        unitCost = totalCost / totalUnits;
      }
      return [part.id, round(unitCost)];
    }),
  );
}

export function calculateDonorEconomics(
  input: DonorEconomicsInput,
): DonorEconomics {
  const totalCost = round(input.purchasePrice + input.extraCosts);
  const income = round(input.soldRevenue + input.scrapIncome);
  const profit = round(income - totalCost);
  const paybackPercent =
    totalCost > 0 ? Math.round((income / totalCost) * 1000) / 10 : null;

  return {
    ...input,
    totalCost,
    income,
    profit,
    paybackPercent,
    isPaidBack: totalCost > 0 ? income >= totalCost : true,
    forecastProfit: round(
      income + input.pendingRevenue + input.stockValue - totalCost,
    ),
  };
}
