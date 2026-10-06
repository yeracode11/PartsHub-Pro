import { ConflictException, NotFoundException } from '@nestjs/common';
import { ItemsService } from './items.service';
import { PartCrossReference } from './entities/part-cross-reference.entity';
import { PartCompatibility } from './entities/part-compatibility.entity';
import { Item } from './entities/item.entity';

const ORG = 'org-a';

function makeQb(result: unknown) {
  const qb: Record<string, jest.Mock> = {};
  for (const method of [
    'leftJoin',
    'leftJoinAndSelect',
    'addSelect',
    'where',
    'andWhere',
    'orderBy',
    'addOrderBy',
    'limit',
    'offset',
  ]) {
    qb[method] = jest.fn(() => qb);
  }
  qb.getOne = jest.fn().mockResolvedValue(result);
  qb.getMany = jest.fn().mockResolvedValue(result ? [result] : []);
  qb.getManyAndCount = jest
    .fn()
    .mockResolvedValue([result ? [result] : [], result ? 1 : 0]);
  return qb;
}

function setup(result: unknown = { id: 1, organizationId: ORG, price: '100' }) {
  const qb = makeQb(result);
  const manager = {
    save: jest.fn(async (_entity, data) => ({ id: 1, ...data })),
    create: jest.fn((_entity, data) => data),
    update: jest.fn(),
    delete: jest.fn(),
    insert: jest.fn(),
  };
  const repo = {
    createQueryBuilder: jest.fn(() => qb),
    findOne: jest.fn(),
    manager: { transaction: jest.fn(async (cb) => cb(manager)) },
  };
  const audit = { record: jest.fn() };
  const service = new ItemsService(repo as never, audit as never);
  return { service, qb, repo, manager, audit };
}

/** Параметры условия поиска (подзапрос с UNION по товарам и аналогам). */
const searchParams = (qb: Record<string, jest.Mock>) =>
  qb.andWhere.mock.calls.find(
    ([condition]) =>
      typeof condition === 'string' && condition.includes('SELECT i.id'),
  )?.[1];

/** Все строки условий, переданные в andWhere/where, одной строкой — для проверок по SQL. */
const conditions = (qb: Record<string, jest.Mock>) =>
  [...qb.where.mock.calls, ...qb.andWhere.mock.calls]
    .map(([condition]) =>
      typeof condition === 'string' ? condition : 'brackets',
    )
    .join('\n');

describe('ItemsService', () => {
  describe('изоляция организаций', () => {
    it('карточка ищется только в своей организации, донор — тоже', async () => {
      const { service, qb } = setup({ id: 1, donor: { id: 7 } });

      await service.findOne(1, ORG);

      expect(qb.where).toHaveBeenCalledWith(
        'item.organizationId = :organizationId',
        { organizationId: ORG },
      );
      expect(qb.leftJoin).toHaveBeenCalledWith(
        'item.donor',
        'donor',
        'donor.organizationId = item.organizationId',
      );
      const donorFields = qb.addSelect.mock.calls[0][0] as string[];
      expect(donorFields).not.toContain('donor.purchasePrice');
    });

    it('чужой товар — 404, а не 500', async () => {
      const { service } = setup(null);
      await expect(service.findOne(1, 'org-b')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('поиск по аналогам ограничен организацией товара', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, { search: '04465-12345' });

      const condition = qb.andWhere.mock.calls.find(
        ([sql]) => typeof sql === 'string' && sql.includes('SELECT i.id'),
      )?.[0] as string;
      expect(condition).toContain('i."organizationId" = :organizationId');
      expect(condition).toContain('x."organizationId" = :organizationId');
      expect(condition).toContain(`ESCAPE '\\'`);
      expect(searchParams(qb)).toMatchObject({
        searchNormalized: '0446512345',
        searchNormalizedLike: '%0446512345%',
      });
    });

    it('правка не трогает товар другой организации', async () => {
      const { service } = setup(null);
      await expect(
        service.update(1, 'org-b', { price: 1 }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('закупочная цена', () => {
    it('кладовщику не выбирается из базы', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, {});
      expect(qb.addSelect).not.toHaveBeenCalledWith('item.purchaseCost');
    });

    it('владельцу выбирается', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, {}, { includeFinance: true });
      expect(qb.addSelect).toHaveBeenCalledWith('item.purchaseCost');
    });

    it('кладовщик не может её поменять', async () => {
      const { service, manager } = setup();
      await service.update(1, ORG, { purchaseCost: 1, name: 'Фара' });
      expect(manager.update).toHaveBeenCalledWith(
        Item,
        { id: 1, organizationId: ORG },
        { name: 'Фара' },
      );
    });

    it('изменение цены пишется в журнал в той же транзакции', async () => {
      const { service, manager, audit } = setup({
        id: 1,
        price: '100.00',
        purchaseCost: '40.00',
      });
      await service.update(
        1,
        ORG,
        { price: 120, purchaseCost: 40 },
        { includeFinance: true, actorId: 'user-1' },
      );
      expect(audit.record).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'item',
          userId: 'user-1',
          changes: { price: { from: 100, to: 120 } },
        }),
        manager,
      );
    });
  });

  describe('список', () => {
    it('без limit отдаёт массив, как раньше', async () => {
      const { service } = setup();
      const result = await service.findAll(ORG, {});
      expect(Array.isArray(result)).toBe(true);
    });

    it('с limit отдаёт страницу и общее число', async () => {
      const { service, qb } = setup();
      const result = await service.findAll(ORG, {
        limit: '500',
        offset: '40',
      });
      expect(result).toEqual({
        items: [expect.any(Object)],
        total: 1,
        limit: 100,
        offset: 40,
      });
      expect(qb.limit).toHaveBeenCalledWith(100);
      expect(qb.offset).toHaveBeenCalledWith(40);
    });

    it('строка «false» в query не включает фильтр наличия', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, { inStock: 'false' });
      expect(conditions(qb)).toContain('item.quantity = 0');
      expect(conditions(qb)).not.toContain('item.quantity > 0');
    });

    it('поиск по коду для сканера ищет точно и сравнивает OEM без разделителей', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, { code: '04465 12345' });
      const brackets = qb.andWhere.mock.calls.find(
        ([condition]) => typeof condition !== 'string',
      );
      expect(brackets?.[1]).toEqual({
        code: '04465 12345',
        codeNormalized: '0446512345',
      });
      expect(qb.limit).toHaveBeenCalledWith(20);
    });

    it('% в запросе ищется буквально', async () => {
      const { service, qb } = setup();
      await service.findAll(ORG, { search: '50%' });
      expect(searchParams(qb).searchLike).toBe('%50\\%%');
    });
  });

  describe('создание и правка каталога', () => {
    it('нормализует OEM и сохраняет оригинал', async () => {
      const { service, manager } = setup();
      await service.create(ORG, {
        name: 'Колодки',
        price: 1000,
        oem: ' 04465-12345 ',
      });
      expect(manager.create).toHaveBeenCalledWith(
        Item,
        expect.objectContaining({
          organizationId: ORG,
          oem: '04465-12345',
          oemNormalized: '0446512345',
        }),
      );
    });

    it('не даёт подменить организацию и донора через тело запроса', async () => {
      const { service, manager } = setup();
      await service.create(ORG, {
        name: 'Фара',
        price: 1,
        organizationId: 'org-b',
        donorId: 99,
        id: 5,
      });
      const data = manager.create.mock.calls[0][1];
      expect(data.organizationId).toBe(ORG);
      expect(data).not.toHaveProperty('donorId');
      expect(data).not.toHaveProperty('id');
    });

    it('заменяет аналоги и применимость целым списком в своей организации', async () => {
      const { service, manager } = setup();
      await service.update(1, ORG, {
        crossReferences: [
          { oem: '04465-12345', brand: 'Toyota' },
          { oem: '0446512345' },
          { oem: 'GDB3456', type: 'aftermarket', brand: 'TRW' },
        ],
        compatibility: [
          { make: 'Toyota', model: 'Camry', yearFrom: 2018, yearTo: 2024 },
        ],
      });

      expect(manager.delete).toHaveBeenCalledWith(PartCrossReference, {
        itemId: 1,
        organizationId: ORG,
      });
      const refs = manager.insert.mock.calls.find(
        ([entity]) => entity === PartCrossReference,
      )?.[1];
      expect(refs).toHaveLength(2);
      expect(refs[0]).toMatchObject({ organizationId: ORG, itemId: 1 });
      expect(manager.insert).toHaveBeenCalledWith(PartCompatibility, [
        expect.objectContaining({
          make: 'Toyota',
          model: 'Camry',
          organizationId: ORG,
        }),
      ]);
    });

    it('сообщает о повторяющемся штрихкоде понятной ошибкой', async () => {
      const { service, manager } = setup();
      manager.save.mockRejectedValue(
        Object.assign(new Error('duplicate'), {
          code: '23505',
          constraint: 'UQ_items_org_barcode',
        }),
      );
      await expect(
        service.create(ORG, { name: 'Фара', price: 1, barcode: '123' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });
});
