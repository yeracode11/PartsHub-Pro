import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InventoryService } from './inventory.service';
import { MovementType } from './entities/inventory-movement.entity';
import { WriteOff, WriteOffReason } from './entities/write-off.entity';

@Injectable()
export class WriteOffsService {
  constructor(
    @InjectRepository(WriteOff)
    private readonly writeOffRepository: Repository<WriteOff>,
    private readonly inventoryService: InventoryService,
  ) {}

  async list(organizationId: string) {
    return this.writeOffRepository.find({
      where: { organizationId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async create(
    organizationId: string,
    userId: string | null,
    raw: {
      itemId?: unknown;
      quantity?: unknown;
      reason?: unknown;
      note?: unknown;
    },
  ) {
    const itemId = Number(raw.itemId);
    const quantity = Number(raw.quantity);
    if (!Number.isInteger(itemId) || itemId <= 0) {
      throw new BadRequestException('Укажите товар');
    }
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 10000) {
      throw new BadRequestException('Некорректное количество');
    }
    if (!Object.values(WriteOffReason).includes(raw.reason as WriteOffReason)) {
      throw new BadRequestException('Укажите причину списания');
    }
    const note =
      typeof raw.note === 'string' && raw.note.trim()
        ? raw.note.trim().slice(0, 500)
        : null;

    return this.writeOffRepository.manager.transaction(async (manager) => {
      const saved = await manager.save(
        WriteOff,
        manager.create(WriteOff, {
          organizationId,
          itemId,
          quantity,
          reason: raw.reason as WriteOffReason,
          note,
          userId,
        }),
      );
      await this.inventoryService.apply(
        {
          organizationId,
          itemId,
          type: MovementType.WRITE_OFF,
          quantityDelta: -quantity,
          userId,
          documentType: 'write_off',
          documentId: saved.id,
          reason: note ?? String(raw.reason),
        },
        manager,
      );
      return saved;
    });
  }
}
