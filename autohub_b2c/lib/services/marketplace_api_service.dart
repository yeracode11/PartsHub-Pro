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
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      // Если API недоступен, возвращаем пустой список
      print('API недоступен: $e');
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
      return data.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      // Если API недоступен, возвращаем пустой список
      print('API недоступен: $e');
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

  // Mock data для fallback
  List<Product> _getMockProducts() {
    return [
      Product(
        id: 1,
        name: 'Фары передние LED Toyota Camry',
        description: 'Высококачественные LED фары для Toyota Camry 2018-2023',
        category: 'Оптика',
        brand: 'Toyota',
        sku: 'TOY-LED-001',
        price: 45000,
        stock: 15,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'AutoParts Pro',
        sellerId: 1,
        rating: 4.5,
        reviewCount: 23,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 2,
        name: 'Масло моторное синтетическое 5W-30',
        description: 'Полностью синтетическое моторное масло для всех типов двигателей',
        category: 'Расходники',
        brand: 'Castrol',
        sku: 'OIL-SYN-001',
        price: 12000,
        stock: 50,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'OilMaster',
        sellerId: 2,
        rating: 4.8,
        reviewCount: 156,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 3,
        name: 'Тормозные колодки передние Honda Accord',
        description: 'Оригинальные тормозные колодки для Honda Accord 2015-2020',
        category: 'Тормозная система',
        brand: 'Honda',
        sku: 'HON-BRK-001',
        price: 25000,
        stock: 20,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'BrakeSpecialist',
        sellerId: 3,
        rating: 4.3,
        reviewCount: 89,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 4,
        name: 'Фильтр воздушный BMW X5',
        description: 'Воздушный фильтр для BMW X5 F15 2013-2018',
        category: 'Фильтры',
        brand: 'BMW',
        sku: 'BMW-AIR-001',
        price: 8000,
        stock: 30,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'BMWParts Direct',
        sellerId: 4,
        rating: 4.7,
        reviewCount: 67,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 5,
        name: 'Свечи зажигания комплект Mercedes E-Class',
        description: 'Комплект свечей зажигания для Mercedes E-Class W213',
        category: 'Двигатель',
        brand: 'Mercedes',
        sku: 'MER-SPK-001',
        price: 18000,
        stock: 10,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'MercedesParts',
        sellerId: 5,
        rating: 4.6,
        reviewCount: 34,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 6,
        name: 'Амортизаторы передние Audi A4',
        description: 'Газовые амортизаторы для Audi A4 B8 2008-2016',
        category: 'Подвеска',
        brand: 'Audi',
        sku: 'AUD-SUS-001',
        price: 35000,
        stock: 8,
        condition: 'new',
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300&h=200&fit=crop&auto=format'],
        sellerName: 'SuspensionPro',
        sellerId: 6,
        rating: 4.4,
        reviewCount: 45,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
