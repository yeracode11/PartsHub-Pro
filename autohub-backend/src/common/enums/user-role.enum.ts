export enum UserRole {
  SUPERADMIN = 'superadmin', // Платформенный админ (macOS admin-приложение и т.п.)
  OWNER = 'owner', // Владелец - полный доступ в организации
  MANAGER = 'manager', // Менеджер - заказы, клиенты
  STOREKEEPER = 'storekeeper', // Кладовщик - склад
  WORKER = 'worker', // Мастер/Мойщик - выполнение работ
}

