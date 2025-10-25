import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import 'api/api_client.dart';

class ImageUploadService {
  final ApiClient _apiClient;
  final ImagePicker _imagePicker = ImagePicker();

  ImageUploadService(this._apiClient);

  // Выбор изображений из галереи или камеры
  Future<List<XFile>> pickImages({
    ImageSource source = ImageSource.gallery,
    int maxImages = 5,
  }) async {
    try {
      if (maxImages == 1) {
        final XFile? image = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        return image != null ? [image] : [];
      } else {
        final List<XFile> images = await _imagePicker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        return images.take(maxImages).toList();
      }
    } catch (e) {
      throw Exception('Ошибка выбора изображений: $e');
    }
  }

  // Загрузка изображений на сервер
  Future<List<String>> uploadImages(int itemId, List<XFile> images) async {
    if (images.isEmpty) {
      throw Exception('Нет изображений для загрузки');
    }

    try {
      final FormData formData = FormData();
      
      // Добавляем файлы в FormData
      for (int i = 0; i < images.length; i++) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              images[i].path,
              filename: images[i].name,
            ),
          ),
        );
      }

      // Отправляем запрос на сервер
      final response = await _apiClient.dio.post(
        '/api/items/$itemId/images',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Возвращаем обновленный товар с новыми изображениями
        final item = ItemModel.fromJson(response.data);
        return item.images ?? [];
      } else {
        throw Exception('Ошибка загрузки изображений: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки изображений: $e');
    }
  }

  // Удаление изображения
  Future<void> removeImage(int itemId, String imageUrl) async {
    try {
      final response = await _apiClient.dio.delete(
        '/api/items/$itemId/images/$imageUrl',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Ошибка удаления изображения: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Ошибка удаления изображения: $e');
    }
  }

  // Установка основного изображения
  Future<void> setMainImage(int itemId, String imageUrl) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/items/$itemId/images/main',
        data: {'imageUrl': imageUrl},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Ошибка установки основного изображения: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Ошибка установки основного изображения: $e');
    }
  }

  // Получение полного URL изображения
  String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return '${_apiClient.baseUrl.replaceAll('/api', '')}$imagePath';
  }

  // Проверка размера файла
  bool isValidImageSize(File file, {int maxSizeMB = 5}) {
    final fileSizeInBytes = file.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    return fileSizeInMB <= maxSizeMB;
  }

  // Проверка типа файла
  bool isValidImageType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }
}
