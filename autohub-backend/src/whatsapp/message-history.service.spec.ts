import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MessageHistoryService } from './message-history.service';
import {
  MessageHistory,
  MessageDirection,
} from './entities/message-history.entity';

describe('MessageHistoryService createInbound idempotency', () => {
  let service: MessageHistoryService;
  let repository: jest.Mocked<
    Pick<Repository<MessageHistory>, 'create' | 'save' | 'findOne'>
  >;

  const inboundData = {
    organizationId: 'org-1',
    whatsappConnectionId: 'conn-1',
    phone: '77776442004',
    externalMessageId: 'wamid.unique',
    messageType: 'text',
    message: 'hello',
  };

  beforeEach(async () => {
    repository = {
      create: jest.fn((data) => data as MessageHistory),
      save: jest.fn(),
      findOne: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MessageHistoryService,
        {
          provide: getRepositoryToken(MessageHistory),
          useValue: repository,
        },
      ],
    }).compile();

    service = module.get(MessageHistoryService);
  });

  it('returns created=false when wamid already exists', async () => {
    repository.findOne.mockResolvedValue({
      id: 1,
      externalMessageId: 'wamid.unique',
    } as MessageHistory);

    const result = await service.createInbound(inboundData);

    expect(result).toEqual({
      record: expect.objectContaining({ id: 1 }),
      created: false,
    });
    expect(repository.save).not.toHaveBeenCalled();
  });

  it('returns created=true on new insert', async () => {
    repository.findOne.mockResolvedValueOnce(null);
    repository.save.mockResolvedValue({
      id: 2,
      ...inboundData,
      direction: MessageDirection.INBOUND,
    } as MessageHistory);

    const result = await service.createInbound(inboundData);

    expect(result?.created).toBe(true);
    expect(repository.save).toHaveBeenCalled();
  });

  it('handles unique violation race with created=false', async () => {
    repository.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 3,
        externalMessageId: 'wamid.unique',
      } as MessageHistory);
    repository.save.mockRejectedValue({ code: '23505' });

    const result = await service.createInbound(inboundData);

    expect(result).toEqual({
      record: expect.objectContaining({ id: 3 }),
      created: false,
    });
  });
});
