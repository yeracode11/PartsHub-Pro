// Конфигурация для подключения к реальному бэкенду AutoHub
class BackendConfig {
  // Базовые URL для разных окружений
  static const String devBaseUrl = 'http://localhost:3000/api';
  static const String prodBaseUrl = 'https://api.autohub.kz/api';
  
  // Текущий URL (определяется в runtime)
  static String get baseUrl {
    // В реальном приложении здесь будет логика определения окружения
    return devBaseUrl; // Пока используем dev
  }
  
  // Endpoints для различных модулей
  static const Map<String, String> endpoints = {
    // Аутентификация
    'auth': {
      'login': '/auth/login',
      'refresh': '/auth/refresh',
      'logout': '/auth/logout',
    },
    
    // Дашборд
    'dashboard': {
      'stats': '/dashboard/stats',
      'salesChart': '/dashboard/sales-chart',
    },
    
    // Товары/Запчасти
    'items': {
      'list': '/items',
      'popular': '/items/popular',
      'byId': '/items/{id}',
      'byCategory': '/items?category={category}',
      'search': '/items?search={query}',
    },
    
    // Заказы
    'orders': {
      'list': '/orders',
      'recent': '/orders/recent',
      'byId': '/orders/{id}',
      'create': '/orders',
      'cancel': '/orders/{id}/cancel',
    },
    
    // Автомобили
    'vehicles': {
      'list': '/vehicles',
      'byId': '/vehicles/{id}',
      'create': '/vehicles',
      'update': '/vehicles/{id}',
      'delete': '/vehicles/{id}',
      'updateMileage': '/vehicles/{id}/mileage',
    },
    
    // Клиенты
    'customers': {
      'list': '/customers',
      'top': '/customers/top',
      'byId': '/customers/{id}',
      'create': '/customers',
      'update': '/customers/{id}',
      'delete': '/customers/{id}',
    },
    
    // Пользователи
    'users': {
      'list': '/users',
      'byId': '/users/{id}',
      'create': '/users',
      'update': '/users/{id}',
      'delete': '/users/{id}',
    },
    
    // Организации
    'organizations': {
      'list': '/organizations',
      'byId': '/organizations/{id}',
      'create': '/organizations',
      'update': '/organizations/{id}',
      'delete': '/organizations/{id}',
    },
    
    // Автосервисы (если есть в бэкенде)
    'services': {
      'list': '/services',
      'byId': '/services/{id}',
      'availability': '/services/{id}/availability',
    },
    
    // Записи на сервис
    'appointments': {
      'list': '/appointments',
      'byId': '/appointments/{id}',
      'create': '/appointments',
      'cancel': '/appointments/{id}/cancel',
      'byUser': '/users/{userId}/appointments',
    },
    
    // WhatsApp интеграция
    'whatsapp': {
      'send': '/whatsapp/send',
      'webhook': '/whatsapp/webhook',
    },
  };
  
  // Настройки таймаутов
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Настройки авторизации
  static const String authHeaderName = 'Authorization';
  static const String authHeaderPrefix = 'Bearer ';
  
  // Настройки пагинации
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Настройки кэширования
  static const Duration cacheTimeout = Duration(minutes: 5);
  
  // Настройки retry
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}
