import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/screens/warehouse/item_edit_screen.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/screens/warehouse/label_print_screen.dart';
import 'package:autohub_b2b/widgets/donor_origin_tile.dart';
import 'package:autohub_b2b/widgets/item_listings_section.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late ItemModel item = widget.item;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  Future<void> _loadFull() async {
    final id = widget.item.id;
    if (id == null) return;
    try {
      final full = await ServiceLocator().itemsRepository.getItem(id);
      if (full != null && mounted) setState(() => item = full);
    } catch (_) {}
  }

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
            _buildMainInfoCard(context, currencyFormat),
            const SizedBox(height: 16),

            _buildQuickActions(context),
            const SizedBox(height: 16),
            DonorOriginTile(item: item),
            if (item.id != null) ...[
              const SizedBox(height: 16),
              ItemListingsSection(itemId: item.id!),
            ],

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

    // Преобразуем относительный URL в полный
    String? fullImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        fullImageUrl = imageUrl;
      } else {
        // Добавляем базовый URL API
        final apiClient = ApiClient();
        final baseUrl = apiClient.baseUrl.replaceAll('/api', '');
        fullImageUrl = '$baseUrl$imageUrl';
      }
    }

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: fullImageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: fullImageUrl,
                fit: BoxFit.cover,
                maxWidthDiskCache: 1000,
                maxHeightDiskCache: 1000,
                memCacheWidth: 1000,
                memCacheHeight: 1000,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            )
          : const Center(
              child: Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            ),
    );
  }

  Widget _buildMainInfoCard(BuildContext context, NumberFormat currencyFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
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
                    item.reservedQuantity > 0
                        ? '${item.quantity} · доступно ${item.available}'
                        : '${item.quantity} шт.',
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
                    child: _buildInfoItem('Артикул', item.sku!, Icons.qr_code),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Быстрые действия',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: item.sku == null || item.sku!.isEmpty
                        ? null
                        : () => _copySku(context, item.sku!),
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Скопировать SKU'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => LabelPrintScreen(
                            product: LabelProductData.fromItem(item),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.label_outline),
                    label: const Text('Этикетка PDF'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: item.id == null || item.quantity <= 0
                        ? null
                        : () => _writeOff(context),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Списать'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemEditScreen(item: item),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Редактировать'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _writeOff(BuildContext context) async {
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    var reason = 'damaged';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Списание'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Количество'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Причина'),
                items: const [
                  DropdownMenuItem(value: 'damaged', child: Text('Повреждено')),
                  DropdownMenuItem(value: 'lost', child: Text('Утеря')),
                  DropdownMenuItem(value: 'defect', child: Text('Брак')),
                  DropdownMenuItem(value: 'other', child: Text('Другое')),
                ],
                onChanged: (value) {
                  if (value != null) reason = value;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Списать'),
            ),
          ],
        );
      },
    );
    final quantity = int.tryParse(qty.text.trim());
    final comment = note.text.trim();
    qty.dispose();
    note.dispose();
    if (confirmed != true || !context.mounted) return;
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите количество')));
      return;
    }
    try {
      await ApiClient().dio.post(
        '/api/write-offs',
        data: {
          'itemId': item.id,
          'quantity': quantity,
          'reason': reason,
          if (comment.isNotEmpty) 'note': comment,
        },
      );
      await _loadFull();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Списано')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }

  Future<void> _copySku(BuildContext context, String sku) async {
    await Clipboard.setData(ClipboardData(text: sku));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SKU скопирован'),
        backgroundColor: Colors.green,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            if (item.reservedQuantity > 0) ...[
              _buildDetailRow('В резерве', '${item.reservedQuantity} шт.'),
              _buildDetailRow('Доступно', '${item.available} шт.'),
            ],
            _buildDetailRow('Состояние', _getConditionText(item.condition)),
            if (item.sku != null && item.sku!.isNotEmpty)
              _buildDetailRow('Артикул (SKU)', item.sku!),
            if (item.oem != null) _buildDetailRow('OEM', item.oem!),
            if (item.barcode != null)
              _buildDetailRow('Штрихкод', item.barcode!),
            if (item.brand != null)
              _buildDetailRow('Производитель', item.brand!),
            if (item.internalCode != null)
              _buildDetailRow('Внутренний код', item.internalCode!),
            if (item.purchaseCost != null)
              _buildDetailRow(
                'Закупка',
                '${currencyFormat.format(item.purchaseCost)} ₸',
              ),
            if (item.isArchived) _buildDetailRow('Статус', 'Снят с продажи'),
            if (item.category != null)
              _buildDetailRow('Категория', item.category!),
            if (item.crossReferences != null &&
                item.crossReferences!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Аналоги',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final ref in item.crossReferences!)
                _buildDetailRow(
                  ref.isAftermarket ? 'Неоригинал' : 'Оригинал',
                  [ref.oem, ref.brand].whereType<String>().join(' · '),
                ),
            ],
            if (item.compatibility != null &&
                item.compatibility!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Применимость',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final fit in item.compatibility!)
                _buildDetailRow(fit.title, fit.details ?? '—'),
            ],
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
