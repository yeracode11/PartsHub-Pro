import {
  allocateDonorCost,
  calculateDonorEconomics,
  DonorEconomicsInput,
} from './donor-economics';

describe('allocateDonorCost', () => {
  it('делит вложения пропорционально стоимости снятых деталей', () => {
    // Двигатель 300k + 2 фары по 50k = 400k по ценам; вложено 200k → коэффициент 0.5
    const costs = allocateDonorCost(200_000, [
      { id: 1, price: 300_000, units: 1 },
      { id: 2, price: 50_000, units: 2 },
    ]);

    expect(costs.get(1)).toBe(150_000);
    expect(costs.get(2)).toBe(25_000);
  });

  it('без цен делит вложения поровну на штуки', () => {
    const costs = allocateDonorCost(90_000, [
      { id: 1, price: 0, units: 1 },
      { id: 2, price: 0, units: 2 },
    ]);

    expect(costs.get(1)).toBe(30_000);
    expect(costs.get(2)).toBe(30_000);
  });

  it('без деталей ничего не распределяет', () => {
    expect(allocateDonorCost(100_000, []).size).toBe(0);
  });
});

const base: DonorEconomicsInput = {
  purchasePrice: 0,
  extraCosts: 0,
  scrapIncome: 0,
  soldRevenue: 0,
  pendingRevenue: 0,
  stockValue: 0,
  partsCount: 0,
  unitsInStock: 0,
  unitsSold: 0,
};

describe('calculateDonorEconomics', () => {
  it('считает окупаемость от полной себестоимости (покупка + расходы)', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 800_000,
      extraCosts: 200_000,
      soldRevenue: 450_000,
      scrapIncome: 50_000,
    });

    expect(result.totalCost).toBe(1_000_000);
    expect(result.income).toBe(500_000);
    expect(result.profit).toBe(-500_000);
    expect(result.paybackPercent).toBe(50);
    expect(result.isPaidBack).toBe(false);
  });

  it('прогноз учитывает склад и открытые заказы, но не меняет фактическую прибыль', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 300_000,
      soldRevenue: 200_000,
      pendingRevenue: 40_000,
      stockValue: 160_000,
    });

    expect(result.profit).toBe(-100_000);
    expect(result.forecastProfit).toBe(100_000);
  });

  it('отмечает донора окупившимся, когда доход покрыл вложения', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 100_000,
      soldRevenue: 130_000,
    });

    expect(result.isPaidBack).toBe(true);
    expect(result.paybackPercent).toBe(130);
    expect(result.profit).toBe(30_000);
  });

  it('не делит на ноль, если вложений нет', () => {
    const result = calculateDonorEconomics(base);
    expect(result.paybackPercent).toBeNull();
    expect(result.isPaidBack).toBe(true);
  });
});
