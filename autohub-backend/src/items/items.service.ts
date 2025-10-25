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
      .where('item.quantity > 0') // Только товары в наличии
      .andWhere('item.synced = true'); // Только синхронизированные товары

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

    return await queryBuilder.getMany();
  }

  async getPopularForB2C(limit: number) {
    return await this.itemRepository
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.organization', 'organization')
      .where('item.quantity > 0')
      .andWhere('item.synced = true')
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
      .andWhere('item.synced = true')
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
}

