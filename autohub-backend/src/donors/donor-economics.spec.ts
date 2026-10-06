import {
  allocateDonorCost,
  calculateDonorEconomics,
  DonorEconomicsInput,
  summarizeDonorEconomics,
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
  deliveryCost: 0,
  dismantlingCost: 0,
  otherCosts: 0,
  scrapIncome: 0,
  soldRevenue: 0,
  refunds: 0,
  pendingRevenue: 0,
  stockValue: 0,
  soldListValue: 0,
  pendingListValue: 0,
  writtenOffListValue: 0,
  partsCount: 0,
  unitsInStock: 0,
  unitsSold: 0,
  unitsReserved: 0,
  unitsWrittenOff: 0,
};

describe('calculateDonorEconomics', () => {
  it('считает окупаемость от полной себестоимости (покупка + все статьи расходов)', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 800_000,
      deliveryCost: 120_000,
      dismantlingCost: 50_000,
      otherCosts: 30_000,
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

  it('считает ожидаемую выручку, прибыль и ROI по формулам ТЗ', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 900_000,
      deliveryCost: 60_000,
      dismantlingCost: 40_000,
      soldRevenue: 600_000,
      refunds: 50_000,
      stockValue: 500_000,
      pendingRevenue: 100_000,
    });

    expect(result.totalCost).toBe(1_000_000);
    expect(result.realizedRevenue).toBe(550_000);
    expect(result.remainingValue).toBe(600_000);
    expect(result.expectedRevenue).toBe(1_150_000);
    expect(result.realizedProfit).toBe(-450_000);
    expect(result.expectedProfit).toBe(150_000);
    expect(result.roi).toBe(-45);
    expect(result.expectedRoi).toBe(15);
  });

  it('делит себестоимость машины между проданным, остатком и списанным', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 100_000,
      soldListValue: 100_000,
      stockValue: 200_000,
      pendingListValue: 50_000,
      writtenOffListValue: 50_000,
      unitsSold: 2,
      unitsInStock: 4,
      unitsReserved: 1,
      unitsWrittenOff: 1,
    });

    expect(result.unitsReceived).toBe(8);
    expect(result.remainingCost).toBe(62_500);
    expect(result.writtenOffCost).toBe(12_500);
  });

  it('без цен делит себестоимость остатка по штукам', () => {
    const result = calculateDonorEconomics({
      ...base,
      purchasePrice: 90_000,
      unitsSold: 1,
      unitsInStock: 2,
    });
    expect(result.remainingCost).toBe(60_000);
  });
});

describe('summarizeDonorEconomics', () => {
  it('складывает суммы и считает ROI от итогов, а не средним', () => {
    const summary = summarizeDonorEconomics([
      calculateDonorEconomics({
        ...base,
        purchasePrice: 100_000,
        soldRevenue: 200_000,
      }),
      calculateDonorEconomics({
        ...base,
        purchasePrice: 900_000,
        soldRevenue: 900_000,
      }),
    ]);

    expect(summary.donorsCount).toBe(2);
    expect(summary.totalCost).toBe(1_000_000);
    expect(summary.realizedProfit).toBe(100_000);
    expect(summary.roi).toBe(10);
  });

  it('пустой список не делит на ноль', () => {
    const summary = summarizeDonorEconomics([]);
    expect(summary.donorsCount).toBe(0);
    expect(summary.roi).toBeNull();
  });
});
