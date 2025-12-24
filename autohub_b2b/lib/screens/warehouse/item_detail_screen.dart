import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatelessWidget {
  final ItemModel item;

  const ItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'ru_RU');
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Информация о запчасти'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение товара
            _buildImageSection(),
            const SizedBox(height: 24),
            
            // Основная информация
            _buildMainInfoCard(currencyFormat),
            const SizedBox(height: 16),
            
            // Детали товара
            _buildDetailsCard(currencyFormat),
            const SizedBox(height: 16),
            
            // Складская информация
            if (item.warehouseCell != null || item.warehouseId != null)
              _buildWarehouseCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    String? imageUrl;
    if (item.images != null && item.images!.isNotEmpty) {
      imageUrl = item.images!.first;
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      imageUrl = item.imageUrl;
    }

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                ),
              ),
            )
          : const Center(
              child: Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            ),
    );
  }

  Widget _buildMainInfoCard(NumberFormat currencyFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, size: 32, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.category != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.category!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Цена',
                    '${currencyFormat.format(item.price)} ₸',
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'На складе',
                    '${item.quantity} шт.',
                    Icons.warehouse,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Состояние',
                    _getConditionText(item.condition),
                    Icons.check_circle,
                  ),
                ),
                if (item.sku != null && item.sku!.isNotEmpty)
                  Expanded(
                    child: _buildInfoItem(
                      'Артикул',
                      item.sku!,
                      Icons.qr_code,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(NumberFormat currencyFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Детали',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (item.description != null && item.description!.isNotEmpty) ...[
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildDetailRow('ID товара', item.id?.toString() ?? '—'),
            _buildDetailRow('Цена', '${currencyFormat.format(item.price)} ₸'),
            _buildDetailRow('Количество', '${item.quantity} шт.'),
            _buildDetailRow('Состояние', _getConditionText(item.condition)),
            if (item.sku != null && item.sku!.isNotEmpty)
              _buildDetailRow('Артикул (SKU)', item.sku!),
            if (item.category != null)
              _buildDetailRow('Категория', item.category!),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warehouse, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Складская информация',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (item.warehouseCell != null)
              _buildDetailRow('Ячейка склада', item.warehouseCell!),
            if (item.warehouseId != null)
              _buildDetailRow('ID склада', item.warehouseId!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getConditionText(String condition) {
    switch (condition) {
      case 'new':
        return 'Новый';
      case 'used':
        return 'Б/У';
      case 'refurbished':
        return 'Восстановленный';
      default:
        return condition;
    }
  }
}

