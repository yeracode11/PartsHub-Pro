import { Injectable, NotFoundException, BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { IncomingDoc, IncomingDocStatus, IncomingDocType } from './entities/incoming-doc.entity';
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
    try {
      // Валидация типа
      if (!Object.values(IncomingDocType).includes(dto.type)) {
        throw new Error(`Invalid type: ${dto.type}. Must be one of: ${Object.values(IncomingDocType).join(', ')}`);
      }

      const docNumber = await this.generateDocNumber(organizationId);

      // Валидация userId
      if (!userId || userId.trim() === '') {
        throw new HttpException(
          {
            statusCode: HttpStatus.BAD_REQUEST,
            message: 'User ID is required',
            error: 'Bad Request',
          },
          HttpStatus.BAD_REQUEST,
        );
      }

      // Обработка supplierId - если пустая строка, то null
      const supplierId = dto.supplierId && dto.supplierId.trim() !== '' ? dto.supplierId : null;

      // Проверяем, что userId действительно строка UUID
      if (typeof userId !== 'string' || userId.trim() === '') {
        throw new HttpException(
          {
            statusCode: HttpStatus.BAD_REQUEST,
            message: `Invalid userId: ${userId} (type: ${typeof userId})`,
            error: 'Bad Request',
          },
          HttpStatus.BAD_REQUEST,
        );
      }
      
      // Создаем объект напрямую, без использования create()
      const doc = new IncomingDoc();
      doc.organizationId = organizationId;
      doc.createdById = userId.trim(); // Явно устанавливаем значение и обрезаем пробелы
      doc.docNumber = docNumber;
      doc.date = new Date(dto.date);
      doc.supplierId = supplierId;
      doc.supplierName = dto.supplierName || null;
      doc.type = dto.type;
      doc.warehouse = dto.warehouse || null;
      doc.notes = dto.notes || null;
      doc.docPhotos = dto.docPhotos || null;
      doc.status = IncomingDocStatus.DRAFT;
      doc.totalAmount = 0;

      // Проверяем, что createdById установлен перед сохранением
      if (!doc.createdById) {
        throw new HttpException(
          {
            statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
            message: 'createdById is not set before save',
            error: 'Internal Server Error',
          },
          HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
      
      // Используем прямой SQL запрос для гарантии, что все поля передаются
      // TypeORM может игнорировать createdById из-за связи @ManyToOne
      const queryRunner = this.dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      
      try {
        // Используем прямой SQL запрос для гарантии передачи всех полей
        const insertResult = await queryRunner.query(
          `INSERT INTO "incoming_docs" (
            "id", 
            "organizationId", 
            "docNumber", 
            "date", 
            "supplierId", 
            "supplierName", 
            "type", 
            "status", 
            "warehouse", 
            "notes", 
            "docPhotos", 
            "createdById", 
            "totalAmount"
          ) VALUES (
            gen_random_uuid(),
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
          ) RETURNING *`,
          [
            doc.organizationId,
            doc.docNumber,
            doc.date,
            doc.supplierId,
            doc.supplierName,
            doc.type,
            doc.status,
            doc.warehouse,
            doc.notes,
            doc.docPhotos ? JSON.stringify(doc.docPhotos) : null,
            doc.createdById, // Явно передаем как параметр
            doc.totalAmount,
          ]
        );
        
        await queryRunner.commitTransaction();

        if (!insertResult || insertResult.length === 0) {
          await queryRunner.rollbackTransaction();
          throw new HttpException(
            {
              statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
              message: 'Failed to create document',
              error: 'Internal Server Error',
            },
            HttpStatus.INTERNAL_SERVER_ERROR,
          );
        }
        
        // Получаем созданную запись через репозиторий для правильной десериализации
        const createdDoc = await this.incomingDocRepository.findOne({
          where: { id: insertResult[0].id },
        });
        
        if (!createdDoc) {
          throw new HttpException(
            {
              statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
              message: 'Failed to retrieve created document',
              error: 'Internal Server Error',
            },
            HttpStatus.INTERNAL_SERVER_ERROR,
          );
        }
        
        return createdDoc;
      } catch (error) {
        await queryRunner.rollbackTransaction();
        throw error;
      } finally {
        await queryRunner.release();
      }
    } catch (error) {
      // Проверяем специфичные ошибки БД
      if ((error as any)?.code === '23505') {
        // Unique constraint violation
        throw new HttpException(
          {
            statusCode: HttpStatus.CONFLICT,
            message: 'Накладная с таким номером уже существует',
            error: 'Conflict',
          },
          HttpStatus.CONFLICT,
        );
      }
      if ((error as any)?.code === '42P01') {
        // Table does not exist
        throw new HttpException(
          {
            statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
            message: 'Таблица incoming_docs не существует в базе данных. Проверьте миграции.',
            error: 'Database Error',
          },
          HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
      if ((error as any)?.code === '42704') {
        // Type does not exist (enum)
        throw new HttpException(
          {
            statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
            message: 'Тип данных enum не существует. Проверьте миграции базы данных.',
            error: 'Database Error',
          },
          HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
      
      // Если это уже HttpException, пробрасываем как есть
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Для остальных ошибок создаем HttpException
      throw new HttpException(
        {
          statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
          message: error?.message || 'Ошибка при создании накладной',
          error: 'Internal Server Error',
          details: error?.message,
        },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
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
    // Используем QueryBuilder чтобы избежать загрузки warehouseCell из Item
    const doc = await this.incomingDocRepository
      .createQueryBuilder('doc')
      .leftJoinAndSelect('doc.supplier', 'supplier')
      .leftJoinAndSelect('doc.createdBy', 'createdBy')
      .leftJoinAndSelect('doc.items', 'items')
      .leftJoin('items.item', 'item')
      .addSelect([
        'item.id',
        'item.name',
        'item.sku',
        'item.category',
        'item.price',
        'item.quantity',
        'item.condition',
        'item.description',
        'item.imageUrl',
        'item.images',
        'item.synced',
        'item.syncedToB2C',
        'item.createdAt',
        'item.updatedAt',
        'item.organizationId',
      ])
      .where('doc.id = :id', { id })
      .andWhere('doc.organizationId = :organizationId', { organizationId })
      .getOne();

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
            // Обновляем ячейку склада, если она указана
            if (incomingItem.warehouseCell) {
              item.warehouseCell = incomingItem.warehouseCell;
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
          newItem.warehouseCell = incomingItem.warehouseCell || null;
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

