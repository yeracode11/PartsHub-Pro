export interface DonorEconomicsInput {
  purchasePrice: number;
  deliveryCost: number;
  dismantlingCost: number;
  otherCosts: number;
  scrapIncome: number;
  /** Выручка по завершённым или оплаченным заказам. */
  soldRevenue: number;
  /** Деньги, возвращённые покупателям. До модуля возвратов — 0. */
  refunds: number;
  /** Сумма деталей в открытых заказах (резерв, в работе) по цене заказа. */
  pendingRevenue: number;
  /** Остатки на складе по текущей цене продажи. */
  stockValue: number;
  /** Проданные и зарезервированные штуки по текущей цене — для распределения себестоимости. */
  soldListValue: number;
  pendingListValue: number;
  /** Списанные штуки по цене продажи. До модуля списаний — 0. */
  writtenOffListValue: number;
  partsCount: number;
  unitsInStock: number;
  unitsSold: number;
  unitsReserved: number;
  unitsWrittenOff: number;
}

export interface DonorEconomics extends DonorEconomicsInput {
  extraCosts: number;
  totalCost: number;
  /** Продажи минус возвраты. */
  realizedRevenue: number;
  /** Фактические деньги: выручка с деталей плюс доход вне склада. */
  income: number;
  unitsReceived: number;
  /** Что ещё не продано (склад + резерв) по цене продажи. */
  remainingValue: number;
  /** Доля себестоимости машины, приходящаяся на непроданные штуки. */
  remainingCost: number;
  writtenOffCost: number;
  expectedRevenue: number;
  realizedProfit: number;
  expectedProfit: number;
  /** Прибыль к вложениям, %; null, если вложений нет. */
  roi: number | null;
  expectedRoi: number | null;
  /** Сколько процентов вложений уже вернулось; null, если вложений нет. */
  paybackPercent: number | null;
  isPaidBack: boolean;
  /** Совместимость с клиентами до Phase 2: profit = realizedProfit, forecastProfit = expectedProfit. */
  profit: number;
  forecastProfit: number;
}

const round = (value: number) => Math.round(value * 100) / 100;
const percent = (value: number, base: number) =>
  base > 0 ? Math.round((value / base) * 1000) / 10 : null;

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

/** Та же пропорция, что в allocateDonorCost, но для группы штук сразу. */
function shareOfCost(
  totalCost: number,
  group: { value: number; units: number },
  all: { value: number; units: number },
): number {
  if (all.value > 0) return round((totalCost * group.value) / all.value);
  if (all.units > 0) return round((totalCost * group.units) / all.units);
  return 0;
}

export function calculateDonorEconomics(
  input: DonorEconomicsInput,
): DonorEconomics {
  const extraCosts = round(
    input.deliveryCost + input.dismantlingCost + input.otherCosts,
  );
  const totalCost = round(input.purchasePrice + extraCosts);
  const realizedRevenue = round(input.soldRevenue - input.refunds);
  const income = round(realizedRevenue + input.scrapIncome);
  const remainingValue = round(input.stockValue + input.pendingRevenue);
  const expectedRevenue = round(income + remainingValue);
  const realizedProfit = round(income - totalCost);
  const expectedProfit = round(expectedRevenue - totalCost);

  const unitsRemaining = input.unitsInStock + input.unitsReserved;
  const unitsReceived =
    unitsRemaining + input.unitsSold + input.unitsWrittenOff;
  const remainingListValue = input.stockValue + input.pendingListValue;
  const all = {
    value: remainingListValue + input.soldListValue + input.writtenOffListValue,
    units: unitsReceived,
  };

  return {
    ...input,
    extraCosts,
    totalCost,
    realizedRevenue,
    income,
    unitsReceived,
    remainingValue,
    remainingCost: shareOfCost(
      totalCost,
      { value: remainingListValue, units: unitsRemaining },
      all,
    ),
    writtenOffCost: shareOfCost(
      totalCost,
      { value: input.writtenOffListValue, units: input.unitsWrittenOff },
      all,
    ),
    expectedRevenue,
    realizedProfit,
    expectedProfit,
    roi: percent(realizedProfit, totalCost),
    expectedRoi: percent(expectedProfit, totalCost),
    paybackPercent: percent(income, totalCost),
    isPaidBack: totalCost > 0 ? income >= totalCost : true,
    profit: realizedProfit,
    forecastProfit: expectedProfit,
  };
}

export interface DonorEconomicsSummary {
  donorsCount: number;
  totalCost: number;
  income: number;
  realizedRevenue: number;
  remainingValue: number;
  remainingCost: number;
  expectedRevenue: number;
  realizedProfit: number;
  expectedProfit: number;
  roi: number | null;
  expectedRoi: number | null;
  unitsReceived: number;
  unitsSold: number;
  unitsReserved: number;
  unitsInStock: number;
  unitsWrittenOff: number;
}

/** Итог по нескольким машинам: суммы складываются, ROI считается от сумм, а не усредняется. */
export function summarizeDonorEconomics(
  list: DonorEconomics[],
): DonorEconomicsSummary {
  const sum = (pick: (e: DonorEconomics) => number) =>
    round(list.reduce((acc, e) => acc + pick(e), 0));
  const totalCost = sum((e) => e.totalCost);
  const realizedProfit = sum((e) => e.realizedProfit);
  const expectedProfit = sum((e) => e.expectedProfit);

  return {
    donorsCount: list.length,
    totalCost,
    income: sum((e) => e.income),
    realizedRevenue: sum((e) => e.realizedRevenue),
    remainingValue: sum((e) => e.remainingValue),
    remainingCost: sum((e) => e.remainingCost),
    expectedRevenue: sum((e) => e.expectedRevenue),
    realizedProfit,
    expectedProfit,
    roi: percent(realizedProfit, totalCost),
    expectedRoi: percent(expectedProfit, totalCost),
    unitsReceived: sum((e) => e.unitsReceived),
    unitsSold: sum((e) => e.unitsSold),
    unitsReserved: sum((e) => e.unitsReserved),
    unitsInStock: sum((e) => e.unitsInStock),
    unitsWrittenOff: sum((e) => e.unitsWrittenOff),
  };
}
