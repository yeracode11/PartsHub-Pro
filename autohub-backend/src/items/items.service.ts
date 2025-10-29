import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Item } from './entities/item.entity';

@Injectable()
export class ItemsService {
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

  // CRUD методы для управления товарами
  async findAll(organizationId: string) {
    return await this.itemRepository.find({
      where: { organizationId },
      order: { createdAt: 'DESC' },
    });
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
    console.log('🔍 findAllForB2C called with options:', options);
    
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
    console.log('🔍 SQL Query:', sql);
    console.log('🔍 Query Params:', params);
    
    const items = await queryBuilder.getMany();
    console.log(`✅ findAllForB2C found ${items.length} items`);
    
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
    
    console.log(`✅ Item ${item.id} (${item.name}) synced to B2C marketplace`);
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
    
    console.log(`✅ Synced ${syncedCount} items to B2C marketplace`);
    return { 
      synced: syncedCount, 
      total: items.length,
      message: `Синхронизировано ${syncedCount} из ${items.length} товаров в B2C магазин`
    };
  }
}

