import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';
import '../services/image_upload_service.dart';

class ImageUploadWidget extends StatefulWidget {
  final ItemModel item;
  final ImageUploadService imageUploadService;
  final Function(List<String>) onImagesUpdated;

  const ImageUploadWidget({
    super.key,
    required this.item,
    required this.imageUploadService,
    required this.onImagesUpdated,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  bool _isUploading = false;
  List<String> _currentImages = [];

  @override
  void initState() {
    super.initState();
    _currentImages = widget.item.images ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Изображения товара',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.item.id != null)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadImages,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate),
                label: Text(_isUploading ? 'Загрузка...' : 'Добавить фото'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Отображение текущих изображений
        if (_currentImages.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _currentImages.length,
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUploadService.getImageUrl(_currentImages[index]);
                final isMainImage = widget.item.imageUrl == _currentImages[index];
                
                if (imageUrl.isEmpty) {
                  return Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.broken_image),
                  );
                }
                
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      // Изображение
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                      
                      // Индикатор основного изображения
                      if (isMainImage)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Главное',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // Кнопка удаления
                      if (widget.item.id != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(_currentImages[index]),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      
                      // Кнопка установки как основное
                      if (widget.item.id != null && !isMainImage)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _setMainImage(_currentImages[index]),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Нет изображений',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                if (widget.item.id != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите "Добавить фото"',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndUploadImages() async {
    try {
      // Выбираем изображения
      final images = await widget.imageUploadService.pickImages(
        maxImages: 5 - _currentImages.length,
      );

      if (images.isEmpty) return;

      // Проверяем размер и тип файлов
      for (final image in images) {
        final file = File(image.path);
        if (!widget.imageUploadService.isValidImageSize(file)) {
          _showErrorSnackBar('Файл ${image.name} слишком большой (максимум 5MB)');
          return;
        }
        if (!widget.imageUploadService.isValidImageType(image.path)) {
          _showErrorSnackBar('Неподдерживаемый формат файла ${image.name}');
          return;
        }
      }

      setState(() {
        _isUploading = true;
      });

      // Загружаем изображения
      final uploadedImages = await widget.imageUploadService.uploadImages(
        widget.item.id!,
        images,
      );

      setState(() {
        _currentImages = uploadedImages;
        _isUploading = false;
      });

      widget.onImagesUpdated(_currentImages);
      _showSuccessSnackBar('Изображения успешно загружены');
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar('Ошибка загрузки: $e');
    }
  }

  Future<void> _removeImage(String imageUrl) async {
    try {
      await widget.imageUploadService.removeImage(widget.item.id!, imageUrl);
      
      setState(() {
        _currentImages.remove(imageUrl);
      });
      
      widget.onImagesUpdated(_currentImages);
      _showSuccessSnackBar('Изображение удалено');
    } catch (e) {
      _showErrorSnackBar('Ошибка удаления: $e');
    }
  }

  Future<void> _setMainImage(String imageUrl) async {
    try {
      await widget.imageUploadService.setMainImage(widget.item.id!, imageUrl);
      _showSuccessSnackBar('Основное изображение установлено');
    } catch (e) {
      _showErrorSnackBar('Ошибка установки основного изображения: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
