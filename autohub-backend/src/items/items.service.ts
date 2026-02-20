import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Item } from './entities/item.entity';
import { FilterItemsDto } from './dto/filter-items.dto';

@Injectable()
export class ItemsService {
  private readonly logger = new Logger(ItemsService.name);

  constructor(
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
  ) {}

  async getPopularItems(organizationId: string, limit: number) {
    // Получаем товары отсортированные по количеству (как популярность)
    const items = await this.itemRepository.find({
      where: { organizationId },
      order: { quantity: 'DESC' }, // Чем больше на складе, тем популярнее
      take: limit,
    });

    // Форматируем для совместимости с Flutter API
    const formattedItems = items.map((item) => ({
      id: item.id,
      name: item.name,
      soldCount: item.quantity, // Используем quantity как soldCount для демо
      price: Number(item.price),
      imageUrl: item.imageUrl,
    }));

    return { items: formattedItems };
  }

  // CRUD методы для управления товарами с фильтрацией
  async findAll(organizationId: string, filters?: FilterItemsDto) {
    try {
      
      const queryBuilder = this.itemRepository
        .createQueryBuilder('item')
        .where('item.organizationId = :organizationId', { organizationId });

      // Фильтр по точному поиску по артикулу (SKU) - приоритетный
      if (filters?.sku) {
        queryBuilder.andWhere('item.sku = :sku', { sku: filters.sku });
      }
      
      // Фильтр по поиску (название или артикул) - только если не указан точный SKU
      if (filters?.search && !filters?.sku) {
        queryBuilder.andWhere(
          '(LOWER(item.name) LIKE LOWER(:search) OR LOWER(item.sku) LIKE LOWER(:search))',
          { search: `%${filters.search}%` }
        );
      }

      // Фильтр по категории (одна)
      if (filters?.category) {
        queryBuilder.andWhere('item.category = :category', { category: filters.category });
      }

      // Фильтр по категориям (множественный)
      if (filters?.categories && filters.categories.length > 0) {
        queryBuilder.andWhere('item.category IN (:...categories)', { categories: filters.categories });
      }

      // Фильтр по состоянию
      if (filters?.condition) {
        queryBuilder.andWhere('item.condition = :condition', { condition: filters.condition });
      }

      // Фильтр по цене
      if (filters?.minPrice !== undefined) {
        queryBuilder.andWhere('item.price >= :minPrice', { minPrice: filters.minPrice });
      }
      if (filters?.maxPrice !== undefined) {
        queryBuilder.andWhere('item.price <= :maxPrice', { maxPrice: filters.maxPrice });
      }

      // Фильтр по складу
      if (filters?.warehouseId) {
        queryBuilder.andWhere('item.warehouseId = :warehouseId', { warehouseId: filters.warehouseId });
      }

      // Фильтр по наличию
      if (filters?.inStock !== undefined) {
        if (filters.inStock) {
          queryBuilder.andWhere('item.quantity > 0');
        } else {
          queryBuilder.andWhere('item.quantity = 0');
        }
      }

      // Фильтр по количеству
      if (filters?.minQuantity !== undefined) {
        queryBuilder.andWhere('item.quantity >= :minQuantity', { minQuantity: filters.minQuantity });
      }
      if (filters?.maxQuantity !== undefined) {
        queryBuilder.andWhere('item.quantity <= :maxQuantity', { maxQuantity: filters.maxQuantity });
      }

      // Фильтр по синхронизации с B2C
      if (filters?.syncedToB2C !== undefined) {
        queryBuilder.andWhere('item.syncedToB2C = :syncedToB2C', { syncedToB2C: filters.syncedToB2C });
      }

      // Сортировка
      queryBuilder.orderBy('item.createdAt', 'DESC');

      const items = await queryBuilder.getMany();
      
      return items;
    } catch (error) {
      this.logger.error('Error in findAll items', error.stack);
      // Возвращаем пустой массив при ошибке
      return [];
    }
  }

  async findOne(id: number, organizationId: string) {
    const item = await this.itemRepository.findOne({
      where: { id, organizationId },
    });
    if (!item) {
      throw new Error(`Item with ID ${id} not found`);
    }
    return item;
  }

  async create(organizationId: string, data: Partial<Item>) {
    const item = this.itemRepository.create({
      ...data,
      organizationId,
      syncedToB2C: true, // Автоматически синхронизируем новые товары в B2C
    });
    return await this.itemRepository.save(item);
  }

  async update(id: number, organizationId: string, data: Partial<Item>) {
    await this.findOne(id, organizationId); // Проверка существования
    await this.itemRepository.update({ id, organizationId }, data);
    return await this.findOne(id, organizationId);
  }

  async remove(id: number, organizationId: string) {
    await this.findOne(id, organizationId); // Проверка существования
    await this.itemRepository.delete({ id, organizationId });
    return { success: true };
  }

  // Методы для B2C интеграции
  async findAllForB2C(options: {
    category?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) {
    
    const queryBuilder = this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.quantity > 0'); // Только товары в наличии
      // Временно убираем проверку synced для показа всех товаров

    if (options.category && options.category !== 'Все') {
      queryBuilder.andWhere('item.category = :category', { category: options.category });
    }

    if (options.search) {
      queryBuilder.andWhere(
        '(item.name LIKE :search OR item.description LIKE :search OR item.sku LIKE :search)',
        { search: `%${options.search}%` }
      );
    }

    if (options.limit) {
      queryBuilder.limit(options.limit);
    }

    if (options.offset) {
      queryBuilder.offset(options.offset);
    }

    queryBuilder.orderBy('item.createdAt', 'DESC');

    const sql = queryBuilder.getSql();
    const params = queryBuilder.getParameters();
    
    const items = await queryBuilder.getMany();
    
    return items;
  }

  async getPopularForB2C(limit: number) {
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.quantity > 0')
      // Временно убираем проверку synced
      .orderBy('item.quantity', 'DESC') // Популярность по количеству на складе
      .limit(limit)
      .getMany();
  }

  async findOneForB2C(id: number) {
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.id = :id', { id })
      .andWhere('item.quantity > 0')
      // Убираем проверку synced - показываем все товары в наличии
      .getOne();
  }

  // Получить товары по списку ID (для группировки по продавцам)
  async findItemsByIds(itemIds: number[]) {
    if (itemIds.length === 0) {
      return [];
    }
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.id IN (:...itemIds)', { itemIds })
      .getMany();
  }

  // Методы для работы с изображениями
  async addImages(id: number, organizationId: string, imageUrls: string[]) {
    const item = await this.findOne(id, organizationId);
    
    // Инициализируем массив изображений если его нет
    if (!item.images) {
      item.images = [];
    }
    
    // Добавляем новые изображения
    item.images = [...item.images, ...imageUrls];
    
    // Если это первое изображение, устанавливаем его как основное
    if (!item.imageUrl && imageUrls.length > 0) {
      item.imageUrl = imageUrls[0];
    }
    
    return await this.itemRepository.save(item);
  }

  async removeImage(id: number, organizationId: string, imageUrl: string) {
    const item = await this.findOne(id, organizationId);
    
    if (!item.images) {
      throw new Error('No images found for this item');
    }
    
    // Удаляем изображение из массива
    item.images = item.images.filter(img => img !== imageUrl);
    
    // Если удаляем основное изображение, устанавливаем новое основное
    if (item.imageUrl === imageUrl) {
      item.imageUrl = item.images.length > 0 ? item.images[0] : '';
    }
    
    return await this.itemRepository.save(item);
  }

  async setMainImage(id: number, organizationId: string, imageUrl: string) {
    const item = await this.findOne(id, organizationId);
    
    if (!item.images || !item.images.includes(imageUrl)) {
      throw new Error('Image not found in item images');
    }
    
    item.imageUrl = imageUrl;
    return await this.itemRepository.save(item);
  }

  // Синхронизировать товар в B2C магазин
  async syncToB2C(id: number, organizationId: string) {
    const item = await this.findOne(id, organizationId);
    item.syncedToB2C = true;
    const updatedItem = await this.itemRepository.save(item);
    
    return updatedItem;
  }

  // Синхронизировать все товары организации в B2C
  async syncAllToB2C(organizationId: string) {
    const items = await this.itemRepository.find({
      where: { organizationId },
    });
    
    let syncedCount = 0;
    for (const item of items) {
      if (!item.syncedToB2C) {
        item.syncedToB2C = true;
        await this.itemRepository.save(item);
        syncedCount++;
      }
    }
    
    return { 
      synced: syncedCount, 
      total: items.length,
      message: `Синхронизировано ${syncedCount} из ${items.length} товаров в B2C магазин`
    };
  }
}

