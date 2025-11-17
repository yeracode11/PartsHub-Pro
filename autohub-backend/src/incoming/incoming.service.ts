import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { IncomingDoc, IncomingDocStatus } from './entities/incoming-doc.entity';
import { IncomingItem } from './entities/incoming-item.entity';
import { Item } from '../items/entities/item.entity';
import { CreateIncomingDocDto } from './dto/create-incoming-doc.dto';
import { CreateIncomingItemDto } from './dto/create-incoming-item.dto';
import { UpdateIncomingDocDto } from './dto/update-incoming-doc.dto';

@Injectable()
export class IncomingService {
  constructor(
    @InjectRepository(IncomingDoc)
    private readonly incomingDocRepository: Repository<IncomingDoc>,
    @InjectRepository(IncomingItem)
    private readonly incomingItemRepository: Repository<IncomingItem>,
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
    private readonly dataSource: DataSource,
  ) {}

  // Генерация номера накладной
  private async generateDocNumber(organizationId: string): Promise<string> {
    const year = new Date().getFullYear();
    const count = await this.incomingDocRepository.count({
      where: { organizationId },
    });
    return `ПН-${year}-${String(count + 1).padStart(6, '0')}`;
  }

  // Создание приходной накладной
  async create(organizationId: string, userId: string, dto: CreateIncomingDocDto): Promise<IncomingDoc> {
    const docNumber = await this.generateDocNumber(organizationId);

    const doc = this.incomingDocRepository.create({
      organizationId,
      createdById: userId,
      docNumber,
      date: new Date(dto.date),
      supplierId: dto.supplierId || null,
      supplierName: dto.supplierName || null,
      type: dto.type,
      warehouse: dto.warehouse || null,
      notes: dto.notes || null,
      docPhotos: dto.docPhotos || null,
      status: IncomingDocStatus.DRAFT,
      totalAmount: 0,
    });

    return await this.incomingDocRepository.save(doc);
  }

  // Получение всех накладных организации
  async findAll(organizationId: string, filters?: {
    status?: IncomingDocStatus;
    dateFrom?: Date;
    dateTo?: Date;
  }): Promise<IncomingDoc[]> {
    const queryBuilder = this.incomingDocRepository
      .createQueryBuilder('doc')
      .leftJoinAndSelect('doc.supplier', 'supplier')
      .leftJoinAndSelect('doc.createdBy', 'createdBy')
      .leftJoinAndSelect('doc.items', 'items')
      .where('doc.organizationId = :organizationId', { organizationId })
      .orderBy('doc.createdAt', 'DESC');

    if (filters?.status) {
      queryBuilder.andWhere('doc.status = :status', { status: filters.status });
    }

    if (filters?.dateFrom) {
      queryBuilder.andWhere('doc.date >= :dateFrom', { dateFrom: filters.dateFrom });
    }

    if (filters?.dateTo) {
      queryBuilder.andWhere('doc.date <= :dateTo', { dateTo: filters.dateTo });
    }

    return await queryBuilder.getMany();
  }

  // Получение одной накладной
  async findOne(id: string, organizationId: string): Promise<IncomingDoc> {
    const doc = await this.incomingDocRepository.findOne({
      where: { id, organizationId },
      relations: ['supplier', 'createdBy', 'items', 'items.item'],
    });

    if (!doc) {
      throw new NotFoundException(`Incoming document with ID ${id} not found`);
    }

    return doc;
  }

  // Обновление накладной
  async update(id: string, organizationId: string, dto: UpdateIncomingDocDto): Promise<IncomingDoc> {
    const doc = await this.findOne(id, organizationId);

    if (dto.date) {
      doc.date = new Date(dto.date);
    }
    if (dto.supplierId !== undefined) {
      doc.supplierId = dto.supplierId || null;
    }
    if (dto.supplierName !== undefined) {
      doc.supplierName = dto.supplierName || null;
    }
    if (dto.type) {
      doc.type = dto.type;
    }
    if (dto.warehouse !== undefined) {
      doc.warehouse = dto.warehouse || null;
    }
    if (dto.notes !== undefined) {
      doc.notes = dto.notes || null;
    }
    if (dto.docPhotos !== undefined) {
      doc.docPhotos = dto.docPhotos || null;
    }
    if (dto.status) {
      doc.status = dto.status;
    }

    // Пересчитываем сумму при изменении статуса
    if (dto.status === IncomingDocStatus.DONE && doc.status !== IncomingDocStatus.DONE) {
      await this.recalculateTotal(doc.id);
    }

    return await this.incomingDocRepository.save(doc);
  }

  // Добавление позиции в накладную
  async addItem(docId: string, organizationId: string, dto: CreateIncomingItemDto): Promise<IncomingItem> {
    const doc = await this.findOne(docId, organizationId);

    if (doc.status === IncomingDocStatus.DONE) {
      throw new BadRequestException('Cannot add items to completed document');
    }

    const item = this.incomingItemRepository.create({
      docId: doc.id,
      itemId: dto.itemId || null,
      name: dto.name,
      category: dto.category || null,
      carBrand: dto.carBrand || null,
      carModel: dto.carModel || null,
      vin: dto.vin || null,
      condition: dto.condition || null,
      quantity: dto.quantity,
      purchasePrice: dto.purchasePrice,
      warehouseCell: dto.warehouseCell || null,
      photos: dto.photos || null,
      sku: dto.sku || null,
    });

    const savedItem = await this.incomingItemRepository.save(item);

    // Пересчитываем сумму накладной
    await this.recalculateTotal(doc.id);

    return savedItem;
  }

  // Удаление позиции
  async removeItem(itemId: string, organizationId: string): Promise<void> {
    const item = await this.incomingItemRepository.findOne({
      where: { id: itemId },
      relations: ['doc'],
    });

    if (!item) {
      throw new NotFoundException(`Item with ID ${itemId} not found`);
    }

    if (item.doc.organizationId !== organizationId) {
      throw new NotFoundException(`Item with ID ${itemId} not found`);
    }

    if (item.doc.status === IncomingDocStatus.DONE) {
      throw new BadRequestException('Cannot remove items from completed document');
    }

    await this.incomingItemRepository.remove(item);
    await this.recalculateTotal(item.docId);
  }

  // Пересчет суммы накладной
  private async recalculateTotal(docId: string): Promise<void> {
    const items = await this.incomingItemRepository.find({
      where: { docId },
    });

    const total = items.reduce((sum, item) => {
      return sum + Number(item.purchasePrice) * item.quantity;
    }, 0);

    await this.incomingDocRepository.update(docId, { totalAmount: total });
  }

  // Проведение накладной (обновление остатков)
  async processDocument(docId: string, organizationId: string): Promise<IncomingDoc> {
    const doc = await this.findOne(docId, organizationId);

    if (doc.status === IncomingDocStatus.DONE) {
      throw new BadRequestException('Document is already processed');
    }

    if (!doc.items || doc.items.length === 0) {
      throw new BadRequestException('Cannot process document without items');
    }

    // Проверяем, что все позиции имеют цены и ячейки
    for (const item of doc.items) {
      if (Number(item.purchasePrice) <= 0) {
        throw new BadRequestException(`Item "${item.name}" has invalid price`);
      }
      if (!item.warehouseCell) {
        throw new BadRequestException(`Item "${item.name}" has no warehouse cell`);
      }
    }

    // Используем транзакцию для атомарности
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Обновляем или создаем товары и увеличиваем остатки
      for (const incomingItem of doc.items) {
        if (incomingItem.itemId) {
          // Обновляем существующий товар
          const item = await queryRunner.manager.findOne(Item, {
            where: { id: incomingItem.itemId, organizationId },
          });

          if (item) {
            item.quantity += incomingItem.quantity;
            // Обновляем цену, если она выше текущей (или можно использовать среднюю)
            if (Number(incomingItem.purchasePrice) > Number(item.price)) {
              item.price = incomingItem.purchasePrice;
            }
            await queryRunner.manager.save(item);
          }
        } else {
          // Создаем новый товар для авторазбора
          const newItem = new Item();
          newItem.organizationId = organizationId;
          newItem.name = incomingItem.name;
          newItem.sku = incomingItem.sku || null;
          newItem.category = incomingItem.category || 'Общее';
          newItem.price = incomingItem.purchasePrice;
          newItem.quantity = incomingItem.quantity;
          newItem.condition = incomingItem.condition || 'used';
          newItem.description = incomingItem.vin
            ? `VIN: ${incomingItem.vin}${incomingItem.carBrand ? `, ${incomingItem.carBrand} ${incomingItem.carModel || ''}` : ''}`
            : incomingItem.carBrand
              ? `${incomingItem.carBrand} ${incomingItem.carModel || ''}`
              : null;
          newItem.images = incomingItem.photos || [];
          newItem.syncedToB2C = true; // Автоматически синхронизируем в B2C

          await queryRunner.manager.save(Item, newItem);
        }
      }

      // Обновляем статус накладной
      doc.status = IncomingDocStatus.DONE;
      await queryRunner.manager.save(doc);

      await queryRunner.commitTransaction();

      return await this.findOne(doc.id, organizationId);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  // Удаление накладной
  async remove(id: string, organizationId: string): Promise<void> {
    const doc = await this.findOne(id, organizationId);

    if (doc.status === IncomingDocStatus.DONE) {
      throw new BadRequestException('Cannot delete processed document');
    }

    await this.incomingDocRepository.remove(doc);
  }
}

