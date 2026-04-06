import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/screens/sales/order_detail_screen.dart';
import 'package:autohub_b2b/services/hardware/barcode_scanner_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/repositories/orders_repository.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final dio = ApiClient().dio;
  final OrdersRepository _ordersRepo = ServiceLocator().ordersRepository;
  List<OrderModel> orders = [];
  bool isLoading = true;
  String? error;
  bool isForbidden = false;
  String? forbiddenMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      error = null;
      isForbidden = false;
    });

    try {
      final loadedOrders = await _ordersRepo.getOrders();
      
      if (!mounted) return;
      
      setState(() {
        orders = loadedOrders;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() {
          isForbidden = true;
          forbiddenMessage = (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к разделу «Продажи». Войдите под владельцем или менеджером.';
          isLoading = false;
        });
      } else {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок
          Container(
            padding: EdgeInsets.all(padding),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Продажи',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: isMobile ? 24 : 28,
                    ),
                      ),
                      if (!isMobile) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Управление заказами и продажами',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                      ],
                  ],
                ),
                ),
                if (!isMobile)
                FilledButton.icon(
                  onPressed: () => _showOrderDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Новый заказ'),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showOrderDialog(context),
                    tooltip: 'Новый заказ',
                ),
              ],
            ),
          ),

          // Список заказов
          Expanded(
            child: _buildOrdersList(isMobile: isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList({bool isMobile = false}) {
    if (isForbidden) {
      return UnauthorizedPlaceholder(message: forbiddenMessage);
    }

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

    if (isMobile) {
      return _buildOrdersCards();
    }
    return _buildOrdersTable();
  }

  Widget _buildOrdersCards() {
    final numberFormat = NumberFormat('#,###', 'ru_RU');
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showOrderDialog(context, order: order),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.orderNumber ?? '#${order.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Редактировать'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Удалить', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showOrderDialog(context, order: order);
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, order);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Сумма',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${numberFormat.format(order.total)} ₸',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(order.status),
                          const SizedBox(height: 8),
                          _buildPaymentBadge(order.paymentStatus),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersTable() {
    final numberFormat = NumberFormat('#,###', 'ru_RU');
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isMobile = MediaQuery.of(context).size.width < 768;
    final margin = isMobile ? 16.0 : 24.0;

    return Container(
      margin: EdgeInsets.all(margin),
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
      case 'reserved':
        color = Colors.deepPurple;
        label = 'Забронирован';
        break;
      case 'ready':
        color = Colors.teal;
        label = 'Готов к выдаче';
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

  Future<void> _showOrderDialog(BuildContext context, {OrderModel? order}) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    if (order == null) {
      // Создание нового заказа
      final isEdit = false;
    
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

    final isMobile = MediaQuery.of(context).size.width < 768;
    final orderDialog = _OrderDialog(
      isEdit: isEdit,
      order: order,
      availableItems: availableItems,
      dio: dio,
      onSuccess: _loadOrders,
    );

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => orderDialog),
      );
    } else {
      showDialog(context: context, builder: (_) => orderDialog);
    }
    } else {
      // Просмотр/редактирование существующего заказа
      // Загружаем полную информацию о заказе с товарами
      try {
        final response = await dio.get('/api/orders/${order.id}');
        final orderData = response.data;
        final fullOrder = OrderModel.fromJson(orderData);
        
        if (!context.mounted) return;
        
        // Если это B2C заказ, показываем детальный просмотр
        if (fullOrder.isB2C) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(order: fullOrder, dio: dio),
            ),
          );
          // Если заказ был обновлен, перезагружаем список
          if (result == true) {
            _loadOrders();
          }
        } else {
          // Для обычных заказов показываем диалог редактирования
          List<Map<String, dynamic>> availableItems = [];
          try {
            final itemsResponse = await dio.get('/api/items');
            availableItems = List<Map<String, dynamic>>.from(itemsResponse.data);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка загрузки товаров: $e')),
              );
            }
            return;
          }
          
          if (!context.mounted) return;

          final isMobile = MediaQuery.of(context).size.width < 768;
          final editDialog = _OrderDialog(
            isEdit: true,
            order: fullOrder,
            availableItems: availableItems,
            dio: dio,
            onSuccess: _loadOrders,
          );

          if (isMobile) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => editDialog),
            );
          } else {
            showDialog(context: context, builder: (_) => editDialog);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки заказа: $e')),
          );
        }
      }
    }
  }

  void _showDeleteDialog(BuildContext context, OrderModel order) {
    DialogHelper.showConfirm(
      context: context,
      title: 'Удалить заказ?',
      message: 'Вы уверены что хотите удалить заказ "${order.orderNumber}"?',
      confirmText: 'Удалить',
      isDestructive: true,
      onConfirm: (ctx) async {
        await dio.delete('/api/orders/${order.id}');
        if (context.mounted) {
          Navigator.pop(ctx);
          _loadOrders();
        }
      },
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
  bool reserveEnabled = false;
  int reserveDays = 3;
  DateTime? reserveUntil;
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final BarcodeScannerService _barcodeScanner = BarcodeScannerService();

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      notesController.text = widget.order!.notes ?? '';
      selectedStatus = widget.order!.status;
      selectedPaymentStatus = widget.order!.paymentStatus;
      reserveUntil = widget.order!.reservedUntil;
      reserveEnabled = selectedStatus == 'reserved' || reserveUntil != null;
      if (reserveUntil != null) {
        final diffDays = reserveUntil!.difference(DateTime.now()).inDays;
        if (diffDays > 0) {
          reserveDays = diffDays;
        }
      }
      // Если заказ уже имеет позиции, заполняем selectedItems для редактирования
      if (widget.order!.items != null && widget.order!.items!.isNotEmpty) {
        selectedItems = widget.order!.items!
            .map((oi) => {
                  'id': oi.id,
                  'itemId': oi.itemId,
                  'name': oi.item?['name'] ?? 'Товар #${oi.itemId}',
                  'price': oi.priceAtTime,
                  'quantity': oi.quantity,
                  'imageUrl': (oi.item?['images'] != null &&
                          (oi.item!['images'] as List).isNotEmpty)
                      ? (oi.item!['images'][0] as String)
                      : oi.item?['imageUrl'],
                  'sku': oi.item?['sku'],
                })
            .toList();
      }
    }

    // Настроить сканер штрих‑кодов для режима кассы
    _barcodeScanner.onBarcodeScanned = _onBarcodeScanned;

    // Автофокус на поле ввода штрих‑кода
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _barcodeFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _barcodeScanner.dispose();
    _barcodeFocusNode.dispose();
    _barcodeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  bool get _isMobilePlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Открывает камеру для сканирования штрих-кода / QR-кода (мобильные устройства)
  Future<void> _openCameraScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const _BarcodeScannerPage(),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _onBarcodeScanned(result);
    }
  }

  /// Обработка отсканированного штрих‑кода (как на кассе)
  void _onBarcodeScanned(String barcode) {
    if (!mounted) return;
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;

    // Ищем товар по SKU / коду
    final lower = trimmed.toLowerCase();
    final matchedItem = widget.availableItems.firstWhere(
      (it) {
        final sku = (it['sku'] ?? '').toString().toLowerCase();
        return sku == lower;
      },
      orElse: () => {},
    );

    if (matchedItem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Товар с кодом "$trimmed" не найден'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final itemId = matchedItem['id'] as int?;
    final name = matchedItem['name']?.toString() ?? 'Товар';
    final priceRaw = matchedItem['price'];
    final double price = priceRaw is String
        ? double.tryParse(priceRaw) ?? 0
        : (priceRaw is num ? priceRaw.toDouble() : 0);
    final images = matchedItem['images'] as List?;
    final firstImage =
        images != null && images.isNotEmpty ? images.first.toString() : null;
    final sku = matchedItem['sku']?.toString();

    // Проверяем, есть ли уже этот товар в чеке — увеличиваем количество
    final existingIndex =
        selectedItems.indexWhere((e) => e['id'] == itemId || e['itemId'] == itemId);
    if (existingIndex != -1) {
      setState(() {
        final current = selectedItems[existingIndex];
        final currentQty = (current['quantity'] as int? ?? 0) + 1;
        selectedItems[existingIndex] = {
          ...current,
          'quantity': currentQty,
        };
      });
    } else {
      setState(() {
        selectedItems.add({
          'id': itemId,
          'itemId': itemId,
          'name': name,
          'price': price,
          'quantity': 1,
          'imageUrl': firstImage,
          'sku': sku,
        });
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлен товар: $name (x1)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // Очистить поле ввода и снова сфокусировать его
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  void _setReserveUntilFromDays() {
    reserveUntil = DateTime.now().add(Duration(days: reserveDays));
  }

  Widget _buildReserveSection() {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final reserveLabel = reserveUntil != null
        ? 'Резерв до ${dateFormat.format(reserveUntil!)}'
        : 'Резервирование выключено';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: reserveEnabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Резерв запчасти'),
            subtitle: Text(
              reserveLabel,
              style: const TextStyle(fontSize: 12),
            ),
            onChanged: (value) {
              setState(() {
                reserveEnabled = value;
                if (reserveEnabled) {
                  selectedStatus = 'reserved';
                  _setReserveUntilFromDays();
                } else {
                  reserveUntil = null;
                  if (selectedStatus == 'reserved') {
                    selectedStatus = 'pending';
                  }
                }
              });
            },
          ),
          if (reserveEnabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: reserveDays,
              decoration: const InputDecoration(
                labelText: 'Срок резерва',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 день')),
                DropdownMenuItem(value: 3, child: Text('3 дня')),
                DropdownMenuItem(value: 7, child: Text('7 дней')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  reserveDays = value;
                  _setReserveUntilFromDays();
                });
              },
            ),
          ],
        ],
      ),
    );
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) return _buildMobileLayout(context);
    return _buildDesktopDialog(context);
  }

  // ========================= MOBILE: Full-screen Scaffold =========================

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Редактировать заказ' : 'Новый заказ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton(
            onPressed: selectedItems.isEmpty ? null : _createOrder,
            child: Text(widget.isEdit ? 'Сохранить' : 'Создать'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Сканер / ввод кода — sticky сверху
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Штрихкод / артикул',
                          prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                          suffixIcon: _isMobilePlatform
                              ? IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _openCameraScanner,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (value) => _barcodeScanner.handleInput(value),
                        onEditingComplete: () {
                          _barcodeScanner.clearBuffer();
                          _barcodeController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Товар'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(height: 1),
              ],
            ),
          ),

          // Список товаров
          Expanded(
            child: selectedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Сканируйте товар\nили добавьте вручную',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: selectedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildMobileItemCard(index),
                  ),
          ),

          // Итого + настройки — sticky снизу
          _buildMobileBottomPanel(context),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(int index) {
    final item = selectedItems[index];
    final price = double.tryParse(item['price'].toString()) ?? 0;
    final quantity = item['quantity'] as int;
    final subtotal = price * quantity;
    final imageUrl = item['imageUrl'] as String?;
    final sku = item['sku'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl.startsWith('http')
                          ? imageUrl
                          : 'http://78.140.246.83:3000$imageUrl',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      maxWidthDiskCache: 200,
                      maxHeightDiskCache: 200,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      placeholder: (_, __) => Container(width: 56, height: 56, color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => Container(
                        width: 56, height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 24),
                    ),
            ),
            const SizedBox(width: 12),

            // Инфо
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sku != null && sku.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sku, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  const SizedBox(height: 8),

                  // Кол-во + цена
                  Row(
                    children: [
                      // Stepper
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stepperBtn(Icons.remove, () {
                              setState(() {
                                final q = quantity - 1;
                                if (q <= 0) {
                                  selectedItems.removeAt(index);
                                } else {
                                  selectedItems[index] = {...item, 'quantity': q};
                                }
                              });
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                            _stepperBtn(Icons.add, () {
                              setState(() {
                                selectedItems[index] = {...item, 'quantity': quantity + 1};
                              });
                            }),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${NumberFormat('#,###', 'ru_RU').format(subtotal)} ₸',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Удалить
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => selectedItems.removeAt(index)),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildMobileBottomPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Итого
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Итого (${selectedItems.length} поз.)',
                      style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                  Text(
                    '${NumberFormat('#,###', 'ru_RU').format(totalAmount)} ₸',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Статус + Оплата
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Статус',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Ожидание')),
                        DropdownMenuItem(value: 'processing', child: Text('В работе')),
                        DropdownMenuItem(value: 'reserved', child: Text('Бронь')),
                        DropdownMenuItem(value: 'ready', child: Text('Готов')),
                        DropdownMenuItem(value: 'completed', child: Text('Завершен')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Отменен')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedStatus = value!;
                          if (selectedStatus == 'reserved') {
                            reserveEnabled = true;
                            _setReserveUntilFromDays();
                          } else {
                            reserveEnabled = false;
                            reserveUntil = null;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedPaymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Оплата',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Не оплачен')),
                        DropdownMenuItem(value: 'partially_paid', child: Text('Частично')),
                        DropdownMenuItem(value: 'paid', child: Text('Оплачен')),
                      ],
                      onChanged: (v) => setState(() => selectedPaymentStatus = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================= DESKTOP: AlertDialog =========================

  Widget _buildDesktopDialog(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Редактировать заказ' : 'Новый заказ'),
      content: SizedBox(
        width: 700,
        height: 600,
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Штрихкод / артикул',
                      hintText: 'Поднесите сканер и отсканируйте товар',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => _barcodeScanner.handleInput(value),
                    onEditingComplete: () {
                      _barcodeScanner.clearBuffer();
                      _barcodeController.clear();
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
              child: selectedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Сканируйте товар или добавьте вручную',
                              style: TextStyle(color: Colors.grey.shade600)),
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
                        final imageUrl = item['imageUrl'] as String?;
                        final sku = item['sku'] as String?;
                        return ListTile(
                          leading: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl.startsWith('http')
                                        ? imageUrl
                                        : 'http://78.140.246.83:3000$imageUrl',
                                    width: 48, height: 48, fit: BoxFit.cover,
                                    maxWidthDiskCache: 200, maxHeightDiskCache: 200,
                                    memCacheWidth: 200, memCacheHeight: 200,
                                    placeholder: (_, __) => Container(width: 48, height: 48, color: Colors.grey.shade200,
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorWidget: (_, __, ___) => Container(width: 48, height: 48,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                                ),
                          title: Text(item['name'], overflow: TextOverflow.ellipsis, maxLines: 1),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${NumberFormat('#,###', 'ru_RU').format(price)} ₸ × $quantity',
                                  overflow: TextOverflow.ellipsis),
                              if (sku != null && sku.isNotEmpty)
                                Text('Артикул: $sku',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setState(() {
                                    final q = (item['quantity'] as int? ?? 1) - 1;
                                    if (q <= 0) { selectedItems.removeAt(index); }
                                    else { selectedItems[index] = {...item, 'quantity': q}; }
                                  });
                                },
                              ),
                              Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setState(() { selectedItems[index] = {...item, 'quantity': quantity + 1}; });
                                },
                              ),
                              Text('${NumberFormat('#,###', 'ru_RU').format(subtotal)} ₸',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() => selectedItems.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  Text('Итого:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${NumberFormat('#,###', 'ru_RU').format(totalAmount)} ₸',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildReserveSection(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Статус', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Ожидание')),
                      DropdownMenuItem(value: 'processing', child: Text('В работе')),
                      DropdownMenuItem(value: 'reserved', child: Text('Забронирован')),
                      DropdownMenuItem(value: 'ready', child: Text('Готов к выдаче')),
                      DropdownMenuItem(value: 'completed', child: Text('Завершен')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Отменен')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                        if (selectedStatus == 'reserved') { reserveEnabled = true; _setReserveUntilFromDays(); }
                        else { reserveEnabled = false; reserveUntil = null; }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPaymentStatus,
                    decoration: const InputDecoration(labelText: 'Статус оплаты', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Не оплачен')),
                      DropdownMenuItem(value: 'partially_paid', child: Text('Частично')),
                      DropdownMenuItem(value: 'paid', child: Text('Оплачен')),
                    ],
                    onChanged: (v) => setState(() => selectedPaymentStatus = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Примечания', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: selectedItems.isEmpty ? null : _createOrder,
          child: Text(widget.isEdit ? 'Сохранить' : 'Создать заказ'),
        ),
      ],
    );
  }

  void _showAddItemDialog() {
    final availableItemsFiltered = widget.availableItems
        .where((item) => (item['quantity'] as int) > 0)
        .toList();

    if (availableItemsFiltered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных товаров на складе')),
      );
      return;
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final addItemWidget = _AddItemToOrderDialog(
      availableItems: availableItemsFiltered,
      onAdd: (item, quantity) {
        setState(() {
          selectedItems.add({
            'id': item['id'],
            'name': item['name'],
            'price': item['price'],
            'quantity': quantity,
          });
        });
        Navigator.pop(context);
      },
    );

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => addItemWidget),
      );
    } else {
      showDialog(context: context, builder: (_) => addItemWidget);
    }
  }

  Future<void> _createOrder() async {
    if (reserveEnabled && reserveUntil == null) {
      _setReserveUntilFromDays();
    }

    final data = {
      'status': reserveEnabled ? 'reserved' : selectedStatus,
      'paymentStatus': selectedPaymentStatus,
      'notes': notesController.text.isEmpty ? null : notesController.text,
      'reservedUntil': reserveEnabled ? reserveUntil?.toIso8601String() : null,
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

}

class _AddItemToOrderDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableItems;
  final void Function(Map<String, dynamic> item, int quantity) onAdd;

  const _AddItemToOrderDialog({
    required this.availableItems,
    required this.onAdd,
  });

  @override
  State<_AddItemToOrderDialog> createState() => _AddItemToOrderDialogState();
}

class _AddItemToOrderDialogState extends State<_AddItemToOrderDialog> {
  Map<String, dynamic>? _selectedItem;
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _onItemChanged(Map<String, dynamic>? value) {
    setState(() {
      _selectedItem = value;
      _quantityController.text = '1';
    });
  }

  void _submit() {
    if (_selectedItem == null) return;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final maxQty = _selectedItem!['quantity'] as int;
    if (quantity <= 0 || quantity > maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректное количество')),
      );
      return;
    }
    widget.onAdd(_selectedItem!, quantity);
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Map<String, dynamic>>(
          value: _selectedItem,
          decoration: const InputDecoration(
            labelText: 'Выберите товар',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          isExpanded: true,
          items: widget.availableItems.map((item) {
            final price = double.tryParse(item['price'].toString()) ?? 0;
            return DropdownMenuItem(
              value: item,
              child: Text(
                '${item['name']} - ${NumberFormat('#,###', 'ru_RU').format(price)} ₸ (${item['quantity']})',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) {
            return widget.availableItems.map((item) {
              final price = double.tryParse(item['price'].toString()) ?? 0;
              return Text(
                '${item['name']} - ${NumberFormat('#,###', 'ru_RU').format(price)} ₸',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              );
            }).toList();
          },
          onChanged: _onItemChanged,
        ),
        const SizedBox(height: 16),
        if (_selectedItem != null)
          TextField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Количество',
              border: const OutlineInputBorder(),
              helperText: 'Доступно: ${_selectedItem!['quantity']}',
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Добавить товар'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          actions: [
            FilledButton(
              onPressed: _selectedItem == null ? null : _submit,
              child: const Text('Добавить'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildContent(),
        ),
      );
    }
    return AlertDialog(
      title: const Text('Добавить товар'),
      content: SizedBox(
        width: 400,
        child: _buildContent(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _selectedItem == null ? null : _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

/// Полноэкранная страница камеры для сканирования штрих-кода / QR-кода.
/// Возвращает отсканированный код через Navigator.pop().
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _returned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;
    _returned = true;
    Navigator.of(context).pop(barcode.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Сканирование'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Фонарик',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Переключить камеру',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Наведите камеру на штрих-код или QR-код',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
