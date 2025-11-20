import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final Dio dio;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.dio,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  String selectedStatus = 'pending';
  String selectedPaymentStatus = 'pending';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.order.status;
    selectedPaymentStatus = widget.order.paymentStatus;
  }

  Future<void> _saveOrder() async {
    setState(() {
      isSaving = true;
    });

    try {
      await widget.dio.put(
        '/api/orders/${widget.order.id}',
        data: {
          'status': selectedStatus,
          'paymentStatus': selectedPaymentStatus,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ обновлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Возвращаем true для обновления списка
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления заказа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = AppTheme.successGradient.colors[0];
        label = 'Завершен';
        break;
      case 'processing':
        color = Colors.blue.shade400;
        label = 'В работе';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Отменен';
        break;
      default:
        color = AppTheme.warningGradient.colors[0];
        label = 'Ожидание';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'paid':
        color = AppTheme.successGradient.colors[0];
        label = 'Оплачен';
        break;
      case 'partially_paid':
        color = AppTheme.warningGradient.colors[0];
        label = 'Частично';
        break;
      default:
        color = Colors.grey;
        label = 'Не оплачен';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###', 'ru_RU');
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final items = widget.order.items ?? [];
    
    // Если товаров нет, показываем сообщение
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Заказ ${widget.order.orderNumber ?? '#${widget.order.id}'}'),
        ),
        body: const Center(
          child: Text('Товары в заказе не найдены'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${widget.order.orderNumber ?? '#${widget.order.id}'}'),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveOrder,
              tooltip: 'Сохранить изменения',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация о заказе
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Номер заказа',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.order.orderNumber ?? '#${widget.order.id}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.order.isB2C)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'B2C Заказ',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Статус',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedStatus,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('Ожидание')),
                                  DropdownMenuItem(value: 'processing', child: Text('В работе')),
                                  DropdownMenuItem(value: 'completed', child: Text('Завершен')),
                                  DropdownMenuItem(value: 'cancelled', child: Text('Отменен')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedStatus = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Статус оплаты',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedPaymentStatus,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('Не оплачен')),
                                  DropdownMenuItem(value: 'partially_paid', child: Text('Частично')),
                                  DropdownMenuItem(value: 'paid', child: Text('Оплачен')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentStatus = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Сумма заказа',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${numberFormat.format(widget.order.total)} ₸',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Дата создания: ${dateFormat.format(widget.order.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Информация о клиенте
            if (widget.order.customer != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Клиент',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.order.customer!['name'] ?? 'Не указано',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (widget.order.customer!['email'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.order.customer!['email'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                      if (widget.order.customer!['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.order.customer!['phone'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Адрес доставки
            if (widget.order.shippingAddress != null && widget.order.shippingAddress!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Адрес доставки',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.order.shippingAddress!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Товары в заказе
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Товары в заказе (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...items.map((orderItem) {
                      final item = orderItem.item;
                      final itemName = item != null && item['name'] != null
                          ? item['name'] as String
                          : 'Товар #${orderItem.itemId}';
                      
                      // Получаем изображения
                      String? firstImage;
                      if (item != null) {
                        final itemImages = item['images'];
                        if (itemImages is List && itemImages.isNotEmpty) {
                          firstImage = itemImages[0] as String?;
                        } else if (item['imageUrl'] != null) {
                          firstImage = item['imageUrl'] as String?;
                        }
                      }
                      
                      final itemSku = item != null ? item['sku'] as String? : null;
                      
                      // Debug
                      debugPrint('📦 Rendering item: $itemName, image: $firstImage, sku: $itemSku');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Фото товара
                            if (firstImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  firstImage.startsWith('http')
                                      ? firstImage
                                      : 'http://78.140.246.83:3000$firstImage',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    );
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory_2, color: Colors.grey),
                              ),
                            const SizedBox(width: 16),
                            // Информация о товаре
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (itemSku != null && itemSku.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Артикул: $itemSku',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '${numberFormat.format(orderItem.priceAtTime)} ₸',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const Text(' × '),
                                      Text(
                                        '${orderItem.quantity}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${numberFormat.format(orderItem.subtotal)} ₸',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Примечания
            if (widget.order.notes != null && widget.order.notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Примечания',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.order.notes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

