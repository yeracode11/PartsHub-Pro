import { AuditService, diffFields } from './audit.service';

describe('diffFields', () => {
  it('сравнивает деньги из базы и из запроса как числа', () => {
    expect(
      diffFields(
        { purchasePrice: '900000.00', deliveryCost: '0.00' },
        { purchasePrice: 900000, deliveryCost: 50000 },
        ['purchasePrice', 'deliveryCost'],
      ),
    ).toEqual({ deliveryCost: { from: 0, to: 50000 } });
  });

  it('пропускает поля, которых нет в изменении, и не следит за посторонними', () => {
    expect(
      diffFields({ status: 'purchased', brand: 'A' }, { brand: 'B' }, [
        'status',
      ]),
    ).toEqual({});
  });

  it('при создании записывает начальные значения', () => {
    expect(
      diffFields(null, { status: 'purchased', deliveryCost: 0 }, [
        'status',
        'deliveryCost',
      ]),
    ).toEqual({ status: { from: null, to: 'purchased' } });
  });
});

describe('AuditService', () => {
  const makeService = () => {
    const qb: any = {};
    for (const m of [
      'leftJoin',
      'select',
      'where',
      'andWhere',
      'orderBy',
      'limit',
    ]) {
      qb[m] = jest.fn().mockReturnValue(qb);
    }
    qb.getRawMany = jest.fn().mockResolvedValue([{ id: 5 }]);
    const repo: any = {
      insert: jest.fn(),
      createQueryBuilder: jest.fn(() => qb),
    };
    return { service: new AuditService(repo), repo, qb };
  };

  it('не пишет пустые изменения', async () => {
    const { service, repo } = makeService();
    await service.record({
      organizationId: 'org',
      entityType: 'donor_vehicle',
      entityId: 1,
      action: 'update',
      changes: {},
    });
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('пишет через менеджер транзакции, если он передан', async () => {
    const { service, repo } = makeService();
    const txRepo = { insert: jest.fn() };
    const manager: any = { getRepository: jest.fn(() => txRepo) };

    await service.record(
      {
        organizationId: 'org',
        entityType: 'donor_vehicle',
        entityId: 1,
        action: 'update',
        changes: { status: { from: 'a', to: 'b' } },
      },
      manager,
    );

    expect(txRepo.insert).toHaveBeenCalledWith(
      expect.objectContaining({ entityId: '1', userId: null }),
    );
    expect(repo.insert).not.toHaveBeenCalled();
  });

  it('история фильтруется по организации', async () => {
    const { service, qb } = makeService();
    const rows = await service.history('org-a', 'donor_vehicle', 7);
    expect(qb.where).toHaveBeenCalledWith(
      'a."organizationId" = :organizationId',
      { organizationId: 'org-a' },
    );
    expect(qb.andWhere).toHaveBeenCalledWith('a."entityId" = :entityId', {
      entityId: '7',
    });
    expect(rows[0].id).toBe('5');
  });
});
