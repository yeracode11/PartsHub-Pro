import 'package:dio/dio.dart';
import '../models/product_model.dart';
import 'api_client.dart';

class MarketplaceApiService {
  final ApiClient _apiClient;

  MarketplaceApiService(this._apiClient);

  // Получить все товары
  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _apiClient.get(
        '/b2c/parts',
        queryParameters: {
          if (category != null && category != 'Все') 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
      );

      final data = response.data['data'] as List<dynamic>;
      
      // Возвращаем пустой список, если данных нет
      if (data.isEmpty) {
        return [];
      }
      
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      // При ошибке возвращаем пустой список
      print('⚠️ Ошибка загрузки товаров: $e');
      return [];
    }
  }

  // Получить популярные товары
  Future<List<Product>> getPopularProducts({int limit = 5}) async {
    try {
      final response = await _apiClient.get(
        '/b2c/parts/popular',
        queryParameters: {'limit': limit},
      );

      final data = response.data['data'] as List<dynamic>;
      
      // Возвращаем пустой список, если данных нет
      if (data.isEmpty) {
        return [];
      }
      
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      // При ошибке возвращаем пустой список
      print('⚠️ Ошибка загрузки популярных товаров: $e');
      return [];
    }
  }

  // Получить товар по ID
  Future<Product> getProduct(int id) async {
    try {
      final response = await _apiClient.get('/b2c/parts/$id');
      return Product.fromJson(response.data['data']);
    } catch (e) {
      // Если API недоступен, выбрасываем исключение
      print('API недоступен: $e');
      throw Exception('Товар не найден');
    }
  }

  // Получить товары по категории
  Future<List<Product>> getProductsByCategory(String category) async {
    return getProducts(category: category);
  }

  // Поиск товаров
  Future<List<Product>> searchProducts(String query) async {
    return getProducts(search: query);
  }
}
