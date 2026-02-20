import '../models/item_model.dart';
import 'api/api_client.dart';

class ItemsService {
  final ApiClient _apiClient = ApiClient();

  // Получить список всех товаров
  Future<List<ItemModel>> getItems() async {
    try {
      final response = await _apiClient.dio.get('/api/items');
      final List<dynamic> data = response.data;
      return data.map((json) => ItemModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load items: $e');
    }
  }

  // Получить товар по ID
  Future<ItemModel> getItem(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/items/$id');
      return ItemModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load item: $e');
    }
  }

  // Найти товар ТОЛЬКО по артикулу (SKU)
  Future<ItemModel?> findItemByCode(String code) async {
    try {
      // Ищем ТОЛЬКО по SKU (артикулу), не по ID
      final response = await _apiClient.dio.get('/api/items', queryParameters: {
        'sku': code.trim(), // Точный поиск по артикулу
      });
      final List<dynamic> data = response.data;

      if (data.isNotEmpty) {
        final item = ItemModel.fromJson(data[0]);
        return item;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

