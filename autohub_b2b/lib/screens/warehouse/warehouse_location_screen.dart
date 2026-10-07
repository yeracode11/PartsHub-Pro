import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:autohub_b2b/widgets/api_error_view.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/screens/warehouse/label_print_screen.dart';
import 'package:autohub_b2b/screens/warehouse/stocktaking_screen.dart';
import 'package:autohub_b2b/services/warehouse_service.dart';

class WarehouseLocationScreen extends StatefulWidget {
  const WarehouseLocationScreen({super.key});

  @override
  State<WarehouseLocationScreen> createState() =>
      _WarehouseLocationScreenState();
}

class _WarehouseLocationScreenState extends State<WarehouseLocationScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _locations = [];
  bool _apiMode = false;
  bool _isLoading = true;
  String? _error;
  bool _isForbidden = false;
  String? _forbiddenMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isForbidden = false;
      _isOffline = false;
    });

    try {
      var useFallback = false;
      try {
        final locations = await dio.get('/api/warehouse-locations');
        if (locations.data is List) {
          if (!mounted) return;
          setState(() {
            _apiMode = true;
            _locations = (locations.data as List)
                .whereType<Map>()
                .map(
                  (row) => {
                    'id': row['id'],
                    'cell': row['code']?.toString() ?? '',
                    'barcode': row['barcode']?.toString(),
                    'warehouseId': row['warehouseId'],
                    'items': <Map<String, dynamic>>[],
                    'totalQuantity': 0,
                    'api': true,
                  },
                )
                .toList();
            _isLoading = false;
          });
          return;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          useFallback = true;
        } else {
          rethrow;
        }
      }
      if (!useFallback) return;

      // Старый сервер без ячеек: группируем текст warehouseCell.
      final response = await dio.get('/api/items');
      final List<dynamic> data = response.data;

      if (!mounted) return;

      // Группируем товары по ячейкам склада
      final Map<String, Map<String, dynamic>> locationMap = {};

      for (var item in data) {
        final warehouseCell = item['warehouseCell'] as String?;
        if (warehouseCell != null && warehouseCell.isNotEmpty) {
          if (!locationMap.containsKey(warehouseCell)) {
            locationMap[warehouseCell] = {
              'cell': warehouseCell,
              'items': <Map<String, dynamic>>[],
              'totalQuantity': 0,
            };
          }
          locationMap[warehouseCell]!['items'].add(item);
          locationMap[warehouseCell]!['totalQuantity'] =
              (locationMap[warehouseCell]!['totalQuantity'] as int) +
              (item['quantity'] as int? ?? 0);
        }
      }

      setState(() {
        _apiMode = false;
        _locations = locationMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        setState(() {
          _isForbidden = true;
          _forbiddenMessage =
              (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к разделу «Расположение». Войдите под владельцем или менеджером.';
          _isLoading = false;
        });
      } else if (isNetworkError(e)) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = userFacingApiMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Расположение товаров'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Инвентаризация',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StocktakingScreen()),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: 'Новая ячейка',
            onPressed: _addCell,
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
          ),
        ),
      ),
      body: _isForbidden
          ? UnauthorizedPlaceholder(
              message: _forbiddenMessage,
              isForbidden: false,
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isOffline
          ? OfflinePlaceholder(onRetry: _loadLocations)
          : _error != null
          ? ApiErrorView(
              error: _error!,
              onRetry: _loadLocations,
              title: 'Ошибка загрузки',
            )
          : _locations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных о расположении',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте ячейку или укажите её в карточке товара',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Поиск
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _apiMode
                          ? 'Код или штрихкод'
                          : 'Поиск по ячейке...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                // Список ячеек
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _locations.length,
                    itemBuilder: (context, index) {
                      final location = _locations[index];
                      final cell = location['cell'] as String;
                      final items = location['items'] as List<dynamic>;
                      final totalQuantity = location['totalQuantity'] as int;

                      // Фильтрация по поиску
                      if (_searchController.text.isNotEmpty) {
                        final query = _searchController.text.toLowerCase();
                        final barcode =
                            (location['barcode'] as String?)?.toLowerCase() ??
                            '';
                        if (!cell.toLowerCase().contains(query) &&
                            !barcode.contains(query)) {
                          return const SizedBox.shrink();
                        }
                      }

                      if (location['api'] == true) {
                        final barcode = location['barcode'] as String?;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(cell),
                            subtitle: Text(
                              (barcode != null && barcode.isNotEmpty)
                                  ? barcode
                                  : 'Без штрихкода',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            trailing: IconButton(
                              tooltip: 'Этикетка',
                              icon: const Icon(Icons.print_outlined),
                              onPressed: () => _printCell(cell, barcode),
                            ),
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            'Ячейка: $cell',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Товаров: ${items.length} | Всего: $totalQuantity шт.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            ...items.map((item) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                ),
                                title: Text(
                                  item['name'] ?? 'Без названия',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: Text(
                                  '${item['quantity'] ?? 0} шт.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
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

  void _printCell(String code, String? barcode) {
    final label = (barcode != null && barcode.isNotEmpty) ? barcode : code;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabelPrintScreen(
          product: LabelProductData(
            productName: code,
            sku: label,
            barcodeData: label,
            showPrice: false,
            showWarehouseCell: false,
          ),
        ),
      ),
    );
  }

  Future<void> _addCell() async {
    final code = TextEditingController();
    final barcode = TextEditingController();
    String? warehouseId;
    List<Map<String, String>> warehouses = [];
    try {
      final list = await WarehouseService().getWarehouses();
      warehouses = list.map((w) => {'id': w.id, 'name': w.name}).toList();
      if (warehouses.isNotEmpty) warehouseId = warehouses.first['id'];
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
      return;
    }
    if (!mounted) return;
    if (warehouses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала создайте склад')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Новая ячейка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: warehouseId,
                decoration: const InputDecoration(labelText: 'Склад'),
                items: warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w['id'],
                        child: Text(w['name'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) => warehouseId = value,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Код'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcode,
                decoration: const InputDecoration(
                  labelText: 'Штрихкод',
                  hintText: 'Если отличается от кода',
                ),
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
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
    final cellCode = code.text.trim();
    final cellBarcode = barcode.text.trim();
    code.dispose();
    barcode.dispose();
    if (confirmed != true || !mounted) return;
    if (cellCode.isEmpty || warehouseId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите склад и код')));
      return;
    }
    try {
      await dio.post(
        '/api/warehouse-locations',
        data: {
          'warehouseId': warehouseId,
          'kind': 'cell',
          'code': cellCode,
          if (cellBarcode.isNotEmpty) 'barcode': cellBarcode,
        },
      );
      await _loadLocations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }
}
