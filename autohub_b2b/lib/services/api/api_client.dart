import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';

/// Глобальный API клиент с автоматическим добавлением JWT токена
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  String get baseUrl => dio.options.baseUrl;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://78.140.246.83:3000', // Production API сервер
        connectTimeout: const Duration(seconds: 60), // Увеличено до 60 секунд
        receiveTimeout: const Duration(seconds: 60), // Увеличено до 60 секунд
        sendTimeout: const Duration(seconds: 60), // Таймаут отправки
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Interceptor для добавления JWT токена
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) async {
          // Обработка 401 - токен истек или невалиден
          if (error.response?.statusCode == 401) {
            try {
              await _storage.clearAll();
            } catch (_) {}
          }

          return handler.next(error);
        },
      ),
    );
  }
}

