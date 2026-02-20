import { DataSource } from 'typeorm';
import { Organization } from '../organizations/entities/organization.entity';
import { Item } from '../items/entities/item.entity';
import { Order } from '../orders/entities/order.entity';
import { Customer } from '../customers/entities/customer.entity';
import { User } from '../users/entities/user.entity';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { BusinessType } from '../common/enums/business-type.enum';
import { UserRole } from '../common/enums/user-role.enum';

export async function seedDatabase(dataSource: DataSource) {
  const organizationRepo = dataSource.getRepository(Organization);
  const itemRepo = dataSource.getRepository(Item);
  const orderRepo = dataSource.getRepository(Order);
  const customerRepo = dataSource.getRepository(Customer);
  const userRepo = dataSource.getRepository(User);
  const vehicleRepo = dataSource.getRepository(Vehicle);

  // Создаем тестовую организацию если не существует
  let org = await organizationRepo.findOne({
    where: { name: 'Тестовый Автосервис' },
  });

  if (!org) {
    org = await organizationRepo.save({
      name: 'Тестовый Автосервис',
      businessType: BusinessType.SERVICE,
      email: 'test@test.com',
      phone: '+77771234567',
      address: 'г. Алматы, ул. Тестовая 1',
    });
  }

  // Создаем реального пользователя ersul143@gmail.com если не существует
  let realUser = await userRepo.findOne({
    where: { email: 'ersul143@gmail.com' },
  });

  if (!realUser) {
    realUser = await userRepo.save({
      firebaseUid: 'ersul143-firebase-uid', // Mock Firebase UID
      email: 'ersul143@gmail.com',
      name: 'Ersul',
      role: UserRole.OWNER,
      organizationId: org.id,
      isActive: true,
    });
  }

  // Создаем тестового пользователя если не существует
  let testUser = await userRepo.findOne({
    where: { email: 'test@test.com' },
  });

  if (!testUser) {
    testUser = await userRepo.save({
      firebaseUid: 'test-firebase-uid', // Mock Firebase UID
      email: 'test@test.com',
      name: 'Тестовый Владелец',
      role: UserRole.OWNER,
      organizationId: org.id,
      isActive: true,
    });
  }


  // Создаем клиентов
  const customers = await customerRepo.save([
    {
      organizationId: org.id,
      name: 'Иван Петров',
      phone: '+77771111111',
      email: 'ivan@example.com',
      carModel: 'Toyota Camry 2020',
      synced: true,
    },
    {
      organizationId: org.id,
      name: 'Мария Сидорова',
      phone: '+77772222222',
      email: 'maria@example.com',
      carModel: 'Honda Accord 2019',
      synced: true,
    },
  ]);

  // Создаем товары (запчасти)
  await itemRepo.save([
    {
      organizationId: org.id,
      name: 'Фары передние LED Toyota',
      sku: 'TOY-LED-001',
      category: 'Оптика',
      price: 45000,
      quantity: 15,
      condition: 'new',
      synced: true,
    },
    {
      organizationId: org.id,
      name: 'Двигатель Honda 2.0',
      sku: 'HON-ENG-200',
      category: 'Двигатели',
      price: 350000,
      quantity: 3,
      condition: 'used',
      synced: true,
    },
    {
      organizationId: org.id,
      name: 'КПП автомат Mazda',
      sku: 'MAZ-TR-AUTO',
      category: 'Трансмиссия',
      price: 180000,
      quantity: 5,
      condition: 'refurbished',
      synced: true,
    },
    {
      organizationId: org.id,
      name: 'Бампер передний BMW',
      sku: 'BMW-BMP-FR',
      category: 'Кузов',
      price: 35000,
      quantity: 8,
      condition: 'new',
      synced: true,
    },
    {
      organizationId: org.id,
      name: 'Капот Mercedes',
      sku: 'MER-HOOD-01',
      category: 'Кузов',
      price: 55000,
      quantity: 4,
      condition: 'used',
      synced: true,
    },
  ]);

  // Создаем заказы
  await orderRepo.save([
    {
      organizationId: org.id,
      orderNumber: 'ORD-2025-001',
      customerId: customers[0].id,
      totalAmount: 500000,
      status: 'processing',
      paymentStatus: 'partially_paid',
      notes: 'Замена двигателя',
      synced: true,
    },
    {
      organizationId: org.id,
      orderNumber: 'ORD-2025-002',
      customerId: customers[1].id,
      totalAmount: 45000,
      status: 'completed',
      paymentStatus: 'paid',
      notes: 'Установка фар',
      synced: true,
    },
    {
      organizationId: org.id,
      orderNumber: 'ORD-2025-003',
      customerId: customers[0].id,
      totalAmount: 180000,
      status: 'pending',
      paymentStatus: 'pending',
      notes: 'КПП на замену',
      synced: true,
    },
  ]);

  // Создаем автомобили
  const vehicles = [
    {
      organizationId: org.id,
      customerId: customers[0].id,
      brand: 'Toyota',
      model: 'Camry',
      year: 2020,
      color: 'Черный',
      plateNumber: 'A123BC77',
      vin: '1HGBH41JXMN109186',
      fuelType: 'petrol' as any,
      transmission: 'automatic' as any,
      engineVolume: '2.5',
      enginePower: 181,
      currentMileage: 45000,
      lastServiceMileage: 40000,
      lastServiceDate: new Date('2024-08-15'),
      nextServiceMileage: 50000,
      nextServiceDate: new Date('2025-02-15'),
      notes: 'Регулярное ТО, без проблем',
      isActive: true,
    },
    {
      organizationId: org.id,
      customerId: customers[0].id,
      brand: 'BMW',
      model: 'X5',
      year: 2018,
      color: 'Белый',
      plateNumber: 'B456DE77',
      vin: '5UXKR0C58J0X74966',
      fuelType: 'diesel' as any,
      transmission: 'automatic' as any,
      engineVolume: '3.0',
      enginePower: 249,
      currentMileage: 89500,
      lastServiceMileage: 85000,
      lastServiceDate: new Date('2024-09-10'),
      nextServiceMileage: 90000,
      nextServiceDate: new Date('2025-01-10'),
      notes: 'Требуется замена тормозных колодок в ближайшее время',
      isActive: true,
    },
    {
      organizationId: org.id,
      customerId: customers[1].id,
      brand: 'Honda',
      model: 'Accord',
      year: 2019,
      color: 'Серебристый',
      plateNumber: 'C789FG77',
      vin: '1HGCV1F39KA024680',
      fuelType: 'petrol' as any,
      transmission: 'cvt' as any,
      engineVolume: '1.5',
      enginePower: 192,
      currentMileage: 62000,
      lastServiceMileage: 60000,
      lastServiceDate: new Date('2024-10-05'),
      nextServiceMileage: 70000,
      nextServiceDate: new Date('2025-04-05'),
      notes: 'Отличное состояние',
      isActive: true,
    },
    {
      organizationId: org.id,
      customerId: customers[1].id,
      brand: 'Mercedes-Benz',
      model: 'E-Class',
      year: 2021,
      color: 'Синий',
      plateNumber: 'E012HI77',
      vin: 'WDDZF4KB5LA234567',
      fuelType: 'hybrid' as any,
      transmission: 'automatic' as any,
      engineVolume: '2.0',
      enginePower: 211,
      currentMileage: 28000,
      lastServiceMileage: 25000,
      lastServiceDate: new Date('2024-09-20'),
      nextServiceMileage: 35000,
      nextServiceDate: new Date('2025-03-20'),
      notes: 'Гибрид, требует специального обслуживания',
      isActive: true,
    },
  ];

  for (const vehicleData of vehicles) {
    await vehicleRepo.save(vehicleData);
  }

}

