import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final dio = ApiClient().dio;
  List<OrderModel> orders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await dio.get('/api/orders');
      final List<dynamic> data = response.data;
      
      setState(() {
        orders = data.map((json) => OrderModel.fromJson(json)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Продажи',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Управление заказами и продажами',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showOrderDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Новый заказ'),
                ),
              ],
            ),
          ),

          // Список заказов
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Нет заказов',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте первый заказ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showOrderDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Новый заказ'),
            ),
          ],
        ),
      );
    }

    return _buildOrdersTable();
  }

  Widget _buildOrdersTable() {
    final numberFormat = NumberFormat('#,###', 'ru_RU');
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Заголовок таблицы
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Номер заказа',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Сумма',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Статус',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Оплата',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Дата создания',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(width: 100), // Для кнопок действий
              ],
            ),
          ),

          // Строки таблицы
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < orders.length - 1
                          ? const BorderSide(color: AppTheme.borderColor)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          order.orderNumber ?? '#${order.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${numberFormat.format(order.total)} ₸',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusBadge(order.status),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildPaymentBadge(order.paymentStatus),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(dateFormat.format(order.createdAt)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showOrderDialog(
                                context,
                                order: order,
                              ),
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _showDeleteDialog(context, order),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

  void _showOrderDialog(BuildContext context, {OrderModel? order}) async {
    final isEdit = order != null;
    
    // Загружаем список товаров
    List<Map<String, dynamic>> availableItems = [];
    try {
      final response = await dio.get('/api/items');
      availableItems = List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки товаров: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => _OrderDialog(
        isEdit: isEdit,
        order: order,
        availableItems: availableItems,
        dio: dio,
        onSuccess: _loadOrders,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: Text(
            'Вы уверены что хотите удалить заказ "${order.orderNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await dio.delete('/api/orders/${order.id}');
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  _loadOrders();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Диалог создания/редактирования заказа с выбором товаров
class _OrderDialog extends StatefulWidget {
  final bool isEdit;
  final OrderModel? order;
  final List<Map<String, dynamic>> availableItems;
  final Dio dio;
  final VoidCallback onSuccess;

  const _OrderDialog({
    required this.isEdit,
    this.order,
    required this.availableItems,
    required this.dio,
    required this.onSuccess,
  });

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final notesController = TextEditingController();
  String selectedStatus = 'pending';
  String selectedPaymentStatus = 'pending';
  List<Map<String, dynamic>> selectedItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      notesController.text = widget.order!.notes ?? '';
      selectedStatus = widget.order!.status;
      selectedPaymentStatus = widget.order!.paymentStatus;
    }
  }

  double get totalAmount {
    return selectedItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item['price'].toString()) ?? 0;
      final quantity = item['quantity'] as int;
      return sum + (price * quantity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Редактировать заказ' : 'Новый заказ'),
      content: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор товаров
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Товары в заказе',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                OutlinedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить товар'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Список выбранных товаров
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: selectedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Товары не выбраны',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: selectedItems.length,
                      itemBuilder: (context, index) {
                        final item = selectedItems[index];
                        final price = double.tryParse(item['price'].toString()) ?? 0;
                        final quantity = item['quantity'] as int;
                        final subtotal = price * quantity;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                          ),
                          title: Text(item['name']),
                          subtitle: Text(
                            '${NumberFormat('#,###', 'ru_RU').format(price)} ₸ × $quantity',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${NumberFormat('#,###', 'ru_RU').format(subtotal)} ₸',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    selectedItems.removeAt(index);
                                  });
                                },
                                tooltip: 'Удалить',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Общая сумма
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Итого:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${NumberFormat('#,###', 'ru_RU').format(totalAmount)} ₸',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Статусы и примечания
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPaymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Статус оплаты',
                      border: OutlineInputBorder(),
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Примечания',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: selectedItems.isEmpty ? null : _createOrder,
          child: Text(widget.isEdit ? 'Сохранить' : 'Создать заказ'),
        ),
      ],
    );
  }

  void _showAddItemDialog() {
    // Фильтруем товары с quantity > 0
    final availableItemsFiltered = widget.availableItems
        .where((item) => (item['quantity'] as int) > 0)
        .toList();

    if (availableItemsFiltered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных товаров на складе')),
      );
      return;
    }

    Map<String, dynamic>? selectedItem;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить товар'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedItem,
                  decoration: const InputDecoration(
                    labelText: 'Выберите товар',
                    border: OutlineInputBorder(),
                  ),
                  items: availableItemsFiltered.map((item) {
                    final price = double.tryParse(item['price'].toString()) ?? 0;
                    return DropdownMenuItem(
                      value: item,
                      child: Text(
                        '${item['name']} - ${NumberFormat('#,###', 'ru_RU').format(price)} ₸ (на складе: ${item['quantity']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedItem = value;
                      quantity = 1; // Reset quantity
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedItem != null)
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Количество',
                      border: const OutlineInputBorder(),
                      helperText: 'Доступно: ${selectedItem!['quantity']}',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      quantity = int.tryParse(value) ?? 1;
                    },
                    controller: TextEditingController(text: quantity.toString()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: selectedItem == null
                  ? null
                  : () {
                      if (quantity <= 0 || quantity > (selectedItem!['quantity'] as int)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Некорректное количество')),
                        );
                        return;
                      }

                      setState(() {
                        selectedItems.add({
                          'id': selectedItem!['id'],
                          'name': selectedItem!['name'],
                          'price': selectedItem!['price'],
                          'quantity': quantity,
                        });
                      });

                      Navigator.pop(dialogContext);
                    },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrder() async {
    final data = {
      'status': selectedStatus,
      'paymentStatus': selectedPaymentStatus,
      'notes': notesController.text.isEmpty ? null : notesController.text,
      'items': selectedItems.map((item) => {
        'itemId': item['id'],
        'quantity': item['quantity'],
      }).toList(),
    };

    try {
      if (widget.isEdit) {
        await widget.dio.put('/api/orders/${widget.order!.id}', data: data);
      } else {
        await widget.dio.post('/api/orders', data: data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Заказ обновлен' : 'Заказ создан'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }
}

