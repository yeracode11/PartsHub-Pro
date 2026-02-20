/// Конфигурация окружения приложения
class Environment {
  // API Base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://78.140.246.83:3000/api',
  );
  
  // Флаг разработки
  static const bool isDevelopment = bool.fromEnvironment(
    'DEVELOPMENT',
    defaultValue: false,
  );
  
  // Таймауты
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // Пагинация
  static const int defaultPageSize = 20;
  
  // Логирование
  static bool get enableApiLogs => isDevelopment;
  
  // Получить текущее окружение
  static String get environment {
    if (apiBaseUrl.contains('localhost')) return 'Development';
    if (apiBaseUrl.contains('staging')) return 'Staging';
    return 'Production';
  }
}

