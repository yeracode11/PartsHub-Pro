export enum BusinessType {
  SERVICE = 'service',      // Автосервис
  PARTS = 'parts',          // Авторазбор
  CARWASH = 'carwash',      // Автомойка
}

export const BusinessFeatures = {
  [BusinessType.SERVICE]: {
    inventory: true,          // Склад запчастей
    orders: true,             // Заказы на работы
    partsRetail: true,        // Продажа запчастей
    crm: true,                // CRM клиенты
    workSchedule: true,       // График работ
    analytics: true,          // Аналитика
  },
  [BusinessType.PARTS]: {
    inventory: true,          // Склад запчастей
    orders: false,            // Заказы на работы НЕТ
    partsRetail: true,        // Продажа запчастей
    crm: true,                // CRM клиенты
    workSchedule: false,      // График работ НЕТ
    analytics: true,          // Аналитика
  },
  [BusinessType.CARWASH]: {
    inventory: false,         // Склад запчастей НЕТ
    orders: true,             // Заказы на мойку
    partsRetail: false,       // Продажа запчастей НЕТ
    crm: true,                // CRM клиенты
    workSchedule: true,       // График работ
    analytics: true,          // Аналитика
  },
};

