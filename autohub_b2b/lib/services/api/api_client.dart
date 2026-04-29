import 'package:dio/dio.dart';
import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/api/api_interceptors.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  String get baseUrl => dio.options.baseUrl;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: Environment.apiBaseUrl.replaceAll('/api', ''),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    attachCoreApiInterceptors(dio);
  }
}
