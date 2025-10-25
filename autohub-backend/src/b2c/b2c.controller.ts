import {
  Controller,
  Get,
  Query,
  Param,
} from '@nestjs/common';
import { ItemsService } from '../items/items.service';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('api/b2c')
export class B2CController {
  constructor(
    private readonly itemsService: ItemsService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  // Публичный endpoint для получения всех запчастей для B2C
  @Get('parts')
  async getParts(
    @Query('category') category?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    // Получаем все товары из всех организаций для B2C
    const items = await this.itemsService.findAllForB2C({
      category,
      search,
      limit: limit ? parseInt(limit) : undefined,
      offset: offset ? parseInt(offset) : undefined,
    });

    // Преобразуем в формат для B2C
    return {
      data: items.map(item => {
        // Обрабатываем изображения - конвертируем относительные пути в полные URL
        let images = item.images && item.images.length > 0 ? item.images : (item.imageUrl ? [item.imageUrl] : []);
        console.log('🔍 Processing images for item', item.id, 'original:', images);
        images = images.map(img => {
          // Если URL уже полный (начинается с http), возвращаем как есть
          if (img.startsWith('http')) {
            return img;
          }
          // Иначе добавляем базовый URL
          const fullUrl = `http://localhost:3000${img}`;
          console.log('📸 Converting image URL:', img, '->', fullUrl);
          return fullUrl;
        });
        console.log('✅ Final images for item', item.id, ':', images);

        return {
          id: item.id,
          name: item.name,
          description: item.description,
          category: item.category,
          brand: item.sku ? item.sku.split('-')[0] : 'Unknown', // Извлекаем бренд из SKU
          sku: item.sku,
          price: Number(item.price),
          stock: item.quantity,
          condition: item.condition,
          images: images,
          sellerName: item.organization?.name || 'AutoHub Store',
          sellerId: item.organizationId,
          rating: 4.5, // Дефолтный рейтинг
          reviewCount: Math.floor(Math.random() * 100) + 10, // Случайное количество отзывов
          isActive: true,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        };
      }),
      total: items.length,
    };
  }

  // Публичный endpoint для получения популярных запчастей
  @Get('parts/popular')
  async getPopularParts(@Query('limit') limit?: string) {
    const limitNum = limit ? parseInt(limit) : 5;
    const items = await this.itemsService.getPopularForB2C(limitNum);

    return {
      data: items.map(item => {
        // Обрабатываем изображения - конвертируем относительные пути в полные URL
        let images = item.images && item.images.length > 0 ? item.images : (item.imageUrl ? [item.imageUrl] : []);
        images = images.map(img => {
          if (img.startsWith('http')) {
            return img;
          }
          return `http://localhost:3000${img}`;
        });

        return {
          id: item.id,
          name: item.name,
          description: item.description,
          category: item.category,
          brand: item.sku ? item.sku.split('-')[0] : 'Unknown',
          sku: item.sku,
          price: Number(item.price),
          stock: item.quantity,
          condition: item.condition,
          images: images,
          sellerName: item.organization?.name || 'AutoHub Store',
          sellerId: item.organizationId,
          rating: 4.5,
          reviewCount: Math.floor(Math.random() * 100) + 10,
          isActive: true,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        };
      }),
    };
  }

  // Публичный endpoint для получения деталей запчасти
  @Get('parts/:id')
  async getPartDetails(@Param('id') id: string) {
    const item = await this.itemsService.findOneForB2C(parseInt(id));
    
    if (!item) {
      throw new Error(`Part with ID ${id} not found`);
    }

    // Обрабатываем изображения - конвертируем относительные пути в полные URL
    let images = item.images && item.images.length > 0 ? item.images : (item.imageUrl ? [item.imageUrl] : []);
    images = images.map(img => {
      if (img.startsWith('http')) {
        return img;
      }
      return `http://localhost:3000${img}`;
    });

    return {
      data: {
        id: item.id,
        name: item.name,
        description: item.description,
        category: item.category,
        brand: item.sku ? item.sku.split('-')[0] : 'Unknown',
        sku: item.sku,
        price: Number(item.price),
        stock: item.quantity,
        condition: item.condition,
        images: images,
        sellerName: item.organization?.name || 'AutoHub Store',
        sellerId: item.organizationId,
        rating: 4.5,
        reviewCount: Math.floor(Math.random() * 100) + 10,
        isActive: true,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      },
    };
  }

  // Публичный endpoint для получения автосервисов
  @Get('services')
  async getServices() {
    const organizations = await this.organizationsService.findAll();
    
    // Фильтруем только автосервисы
    const serviceOrganizations = organizations.filter(org => 
      org.businessType === 'service' && org.isActive
    );

    return {
      data: serviceOrganizations.map(org => ({
        id: org.id,
        name: org.name,
        address: org.address || 'Адрес не указан',
        phone: org.phone || 'Телефон не указан',
        businessType: org.businessType,
        isActive: org.isActive,
        services: [
          'Диагностика двигателя',
          'Замена масла',
          'Ремонт тормозов',
          'Замена фильтров',
          'Диагностика подвески',
          'Ремонт кондиционера',
          'Шиномонтаж',
          'Сварочные работы',
        ],
        servicePrices: {
          'Диагностика двигателя': 15000,
          'Замена масла': 8000,
          'Ремонт тормозов': 25000,
          'Замена фильтров': 5000,
          'Диагностика подвески': 12000,
          'Ремонт кондиционера': 30000,
          'Шиномонтаж': 3000,
          'Сварочные работы': 20000,
        },
        rating: 4.5,
        reviewCount: Math.floor(Math.random() * 50) + 10,
        workingHours: '09:00 - 18:00',
        createdAt: org.createdAt,
        updatedAt: org.updatedAt,
      })),
    };
  }
}
