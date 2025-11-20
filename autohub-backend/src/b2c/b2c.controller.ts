import {
  Controller,
  Get,
  Post,
  Query,
  Param,
  Body,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ItemsService } from '../items/items.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { OrdersService } from '../orders/orders.service';
import { Order } from '../orders/entities/order.entity';

@Controller('api/b2c')
export class B2CController {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly itemsService: ItemsService,
    private readonly organizationsService: OrganizationsService,
    private readonly ordersService: OrdersService,
  ) {}

  // Публичный endpoint для получения всех запчастей для B2C
  @Get('parts')
  async getParts(
    @Query('category') category?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    console.log('📦 B2C getParts called with:', { category, search, limit, offset });
    // Получаем все товары из всех организаций для B2C
    const items = await this.itemsService.findAllForB2C({
      category,
      search,
      limit: limit ? parseInt(limit) : undefined,
      offset: offset ? parseInt(offset) : undefined,
    });
    console.log(`📦 Found ${items.length} items for B2C`);

    // Преобразуем в формат для B2C
    const baseUrl = process.env.API_BASE_URL || 'http://78.140.246.83:3000';
    
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
          // Иначе добавляем базовый URL из переменной окружения
          const fullUrl = `${baseUrl}${img}`;
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
    
    // Используем тот же baseUrl для изображений
    const baseUrl = process.env.API_BASE_URL || 'http://78.140.246.83:3000';

    return {
      data: items.map(item => {
        // Обрабатываем изображения - конвертируем относительные пути в полные URL
        let images = item.images && item.images.length > 0 ? item.images : (item.imageUrl ? [item.imageUrl] : []);
        images = images.map(img => {
          if (img.startsWith('http')) {
            return img;
          }
          return `${baseUrl}${img}`;
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

  // Публичный endpoint для получения всех заказов B2C пользователя
  @Get('orders')
  async getOrders() {
    try {
      // Получаем все заказы из B2C (isB2C = true) из всех организаций
      // В будущем можно добавить фильтрацию по customerId, когда будет авторизация
      console.log('📦 Fetching all B2C orders');
      const orders = await this.orderRepository.find({
        where: { isB2C: true },
        relations: ['customer', 'items', 'items.item', 'organization'],
        order: { createdAt: 'DESC' },
      });
      
      console.log(`✅ Found ${orders.length} B2C orders`);
      
      // Преобразуем заказы в формат для B2C
      const b2cOrders = orders.map(order => ({
        id: order.id,
        orderNumber: order.orderNumber,
        organizationId: order.organizationId,
        sellerName: order.organization?.name || 'Unknown Seller',
        customerId: order.customerId,
        items: (order.items || []).map(item => ({
          id: item.id,
          itemId: item.itemId,
          item: item.item,
          productId: item.itemId,
          productName: item.item?.name || 'Unknown',
          productImage: item.item?.imageUrl || '',
          price: Number(item.priceAtTime),
          priceAtTime: item.priceAtTime,
          quantity: item.quantity,
          total: Number(item.subtotal),
          subtotal: item.subtotal,
        })),
        totalAmount: Number(order.totalAmount),
        status: order.status,
        paymentStatus: order.paymentStatus,
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      }));

      return {
        data: b2cOrders,
        total: b2cOrders.length,
      };
    } catch (error) {
      console.error('❌ Error fetching B2C orders:', error);
      return {
        data: [],
        total: 0,
      };
    }
  }

  // Публичный endpoint для создания заказа B2C
  @Post('orders')
  async createOrder(@Body() data: any) {
    try {
      console.log('📦 ========== Creating B2C order ==========');
      console.log('📦 Request data:', JSON.stringify(data, null, 2));
      
      const items = data.items || [];
      if (items.length === 0) {
        throw new Error('Order must contain at least one item');
      }

      // Если указан organizationId в запросе, используем его (для авторизованных пользователей)
      // Иначе группируем по организациям продавцов товаров
      const targetOrganizationId = data.organizationId;
      console.log('📦 Target organizationId from request:', targetOrganizationId || 'NOT PROVIDED (will group by sellers)');
      
      if (targetOrganizationId) {
        console.log(`📦 Using provided organizationId: ${targetOrganizationId}`);
        
        // Проверяем, что организация существует
        const org = await this.organizationsService.findOne(targetOrganizationId);
        if (!org) {
          throw new Error(`Organization ${targetOrganizationId} not found`);
        }
        
        // Создаем один заказ для указанной организации
        const orderData = {
          items: items.map((item: any) => ({
            itemId: item.itemId,
            quantity: item.quantity,
          })),
          customerId: data.customerId || null,
          notes: data.notes ? `${data.notes} (Заказ из B2C)` : 'Заказ из B2C маркетплейса',
          shippingAddress: data.shippingAddress || null, // Адрес доставки
          status: 'pending',
          paymentStatus: 'pending',
          isB2C: true,
        } as Partial<Order> & { items?: Array<{ itemId: number; quantity: number }>; shippingAddress?: string };

        console.log(`📦 Creating order for organization: ${targetOrganizationId}`);
        const order = await this.ordersService.create(targetOrganizationId, orderData, { skipQuantityCheck: true });
        
        if (!order) {
          throw new Error(`Failed to create order for organization ${targetOrganizationId}`);
        }
        
        console.log(`✅ Order created for organization ${targetOrganizationId}:`, order.id);
        return {
          data: order,
        };
      }

      // Если organizationId не указан, группируем по организациям продавцов
      console.log('📦 No organizationId provided, grouping by seller organizations');
      
      // Получаем информацию о товарах и их организациях-продавцах
      const itemIds = items.map((item: any) => item.itemId);
      console.log(`📦 Fetching items with IDs:`, itemIds);
      
      const itemsWithOrgs = await this.itemsService.findItemsByIds(itemIds);
      console.log(`📦 Found ${itemsWithOrgs.length} items with organization info`);
      
      // Логируем organizationId каждого товара
      itemsWithOrgs.forEach(item => {
        console.log(`   Item ${item.id} (${item.name}): organizationId = ${item.organizationId}`);
      });
      
      if (itemsWithOrgs.length !== itemIds.length) {
        throw new Error('Some items not found');
      }

      // Группируем товары по organizationId (продавцам)
      const itemsBySeller = new Map<string, Array<{ itemId: number; quantity: number }>>();
      
      for (const orderItem of items) {
        const item = itemsWithOrgs.find(i => i.id === orderItem.itemId);
        if (!item) {
          throw new Error(`Item with ID ${orderItem.itemId} not found`);
        }
        
        const orgId = item.organizationId;
        console.log(`   Item ${orderItem.itemId} belongs to organization: ${orgId}`);
        
        if (!itemsBySeller.has(orgId)) {
          itemsBySeller.set(orgId, []);
        }
        itemsBySeller.get(orgId)!.push({
          itemId: orderItem.itemId,
          quantity: orderItem.quantity,
        });
      }

      console.log(`📦 Grouped items into ${itemsBySeller.size} seller(s)`);
      itemsBySeller.forEach((sellerItems, orgId) => {
        console.log(`   Seller ${orgId}: ${sellerItems.length} items`);
      });

      // Создаем отдельный заказ для каждой организации-продавца
      const createdOrders: Order[] = [];
      
      for (const [organizationId, sellerItems] of itemsBySeller.entries()) {
        const orderData = {
          items: sellerItems as Array<{ itemId: number; quantity: number }>,
          customerId: data.customerId || null,
          notes: data.notes ? `${data.notes} (Заказ из B2C)` : 'Заказ из B2C маркетплейса',
          shippingAddress: data.shippingAddress || null, // Адрес доставки
          status: 'pending',
          paymentStatus: 'pending',
          isB2C: true, // Помечаем что это заказ из B2C магазина
        } as Partial<Order> & { items?: Array<{ itemId: number; quantity: number }>; shippingAddress?: string };

        console.log(`📦 Creating order for seller org: ${organizationId}`);
        console.log(`📦 Order items:`, JSON.stringify(sellerItems, null, 2));
        
        // Создаем заказ без проверки количества для B2C
        const order = await this.ordersService.create(organizationId, orderData, { skipQuantityCheck: true });
        
        if (!order) {
          console.error(`❌ Failed to create order for org: ${organizationId}`);
          throw new Error(`Failed to create order for seller ${organizationId}`);
        }
        
        console.log(`✅ Order created for seller ${organizationId}:`, order.id);
        createdOrders.push(order);
      }

      // Если заказ один - возвращаем его напрямую, иначе возвращаем массив
      if (createdOrders.length === 1) {
        return {
          data: createdOrders[0],
        };
      } else {
        return {
          data: createdOrders,
          message: `Created ${createdOrders.length} orders for different sellers`,
        };
      }
    } catch (error) {
      console.error('❌ Error creating B2C order:', error);
      throw error;
    }
  }
}
