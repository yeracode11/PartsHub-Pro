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

          print('🌐 REQUEST: ${options.method} ${options.uri}');
          if (token != null) {
            print('   Token: ${token.substring(0, 20)}...');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (error, handler) async {
          print('❌ ERROR: ${error.response?.statusCode} ${error.requestOptions.uri}');
          print('   Message: ${error.message}');
          print('   Data: ${error.response?.data}');

          // Обработка ошибок подключения
          if (error.type == DioExceptionType.connectionError || 
              error.type == DioExceptionType.connectionTimeout) {
            print('⚠️ Connection Error - Backend server may be down');
            print('   Check if backend is running on: ${error.requestOptions.baseUrl}');
          }

          // Обработка 401 - токен истек или невалиден
          if (error.response?.statusCode == 401) {
            print('⚠️ 401 Error - NOT clearing storage for debugging');
            print('   Error details: ${error.response?.data}');
            print('   Request URL: ${error.requestOptions.uri}');
            print('   Request method: ${error.requestOptions.method}');
            // Временно отключаем автоочистку для отладки
            // try {
            //   final storage = SecureStorageService();
            //   await storage.clearAll();
            //   print('✅ Storage cleared - user needs to re-login');
            // } catch (e) {
            //   print('❌ Error clearing storage: $e');
            // }
          }

          return handler.next(error);
        },
      ),
    );
  }
}

