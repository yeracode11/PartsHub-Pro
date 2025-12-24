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
      print('Error in getItems: $e');
      throw Exception('Failed to load items: $e');
    }
  }

  // Получить товар по ID
  Future<ItemModel> getItem(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/items/$id');
      return ItemModel.fromJson(response.data);
    } catch (e) {
      print('Error in getItem: $e');
      throw Exception('Failed to load item: $e');
    }
  }

  // Найти товар ТОЛЬКО по артикулу (SKU)
  Future<ItemModel?> findItemByCode(String code) async {
    try {
      print('ItemsService: Searching for item with SKU: "$code"');
      
      // Ищем ТОЛЬКО по SKU (артикулу), не по ID
      final response = await _apiClient.dio.get('/api/items', queryParameters: {
        'sku': code.trim(), // Точный поиск по артикулу
      });
      final List<dynamic> data = response.data;
      
      print('ItemsService: Search by SKU "$code" returned ${data.length} items');
      
      if (data.isNotEmpty) {
        final item = ItemModel.fromJson(data[0]);
        print('ItemsService: Found item by SKU - ID: ${item.id}, Name: ${item.name}, SKU: ${item.sku}');
        return item;
      }
      
      print('ItemsService: Item not found for SKU: "$code"');
      return null;
    } catch (e) {
      print('Error in findItemByCode: $e');
      return null;
    }
  }
}

