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
      rethrow;
    }
  }

  // Получить товар по ID
  Future<ItemModel> getItem(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/items/$id');
      return ItemModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Найти товар ТОЛЬКО по артикулу (SKU)
}

