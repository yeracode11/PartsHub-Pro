import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/models/warehouse_model.dart';
import 'package:autohub_b2b/services/warehouse_service.dart';
import 'package:autohub_b2b/widgets/items_filter_widget.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/screens/warehouse/item_edit_screen.dart';
import 'package:autohub_b2b/screens/warehouse/printer_settings_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  final WarehouseService _warehouseService = WarehouseService();
  
  List<ItemModel> items = [];
  List<ItemModel> filteredItems = [];
  List<Warehouse> warehouses = [];
  bool isLoading = true;
  String? error;
  
  // Активные фильтры
  Map<String, dynamic> activeFilters = {};
  int activeFiltersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _loadItems();
  }

  Future<void> _loadWarehouses() async {
    try {
      final loadedWarehouses = await _warehouseService.getWarehouses();
      if (mounted) {
        setState(() {
          warehouses = loadedWarehouses;
        });
      }
    } catch (e) {
      print('Error loading warehouses: $e');
    }
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Подготовка query параметров из activeFilters
      final queryParams = <String, dynamic>{};
      activeFilters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });

      final response = await dio.get('/api/items', queryParameters: queryParams);
      final List<dynamic> data = response.data;

      print('📦 Loaded ${data.length} items from API');
      if (data.isNotEmpty) {
        print('📦 First item sample: ${data[0]}');
      }

      if (!mounted) return;
      
      try {
        final parsedItems = data.map((json) {
          try {
            return ItemModel.fromJson(json);
          } catch (e) {
            print('❌ Error parsing item: $e');
            print('❌ Item data: $json');
            rethrow;
          }
        }).toList();

        setState(() {
          items = parsedItems;
          filteredItems = items;
          isLoading = false;
        });
        
        print('✅ Successfully parsed ${items.length} items');
      } catch (parseError) {
        print('❌ Error parsing items: $parseError');
        if (!mounted) return;
        setState(() {
          error = 'Ошибка обработки данных: $parseError';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading items: $e');
      if (!mounted) return;
      
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredItems = items;
      } else {
        filteredItems = items.where((item) {
          return (item.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (item.sku?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => ItemsFilterWidget(
        warehouses: warehouses,
        onApplyFilters: _applyFilters,
      ),
    );
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      activeFilters = filters;
      activeFiltersCount = filters.values.where((v) => v != null).length;
    });
    _loadItems();
  }

  Widget _buildItemsList({bool isMobile = false}) {
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
              onPressed: _loadItems,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (filteredItems.isEmpty) {
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
                Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              items.isEmpty ? 'Склад пуст' : 'Ничего не найдено',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              items.isEmpty
                  ? 'Начните с добавления первого товара'
                  : 'Попробуйте изменить запрос',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            if (items.isEmpty) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showItemDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Добавить товар'),
              ),
            ],
          ],
        ),
      );
    }

    if (isMobile) {
      return _buildItemsCards(context, filteredItems);
    }
    return _buildItemsTable(context, filteredItems);
  }

  Widget _buildItemsCards(BuildContext context, List<ItemModel> items) {
    final numberFormat = NumberFormat('#,###', 'ru_RU');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ItemEditScreen(item: item),
                ),
              );
            },
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
                          item.name ?? 'Без названия',
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ItemEditScreen(item: item),
                              ),
                            );
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, item);
                          }
                        },
                      ),
                    ],
                  ),
                  if (item.sku != null && item.sku!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Артикул: ${item.sku}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (item.category != null && item.category!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Категория: ${item.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Количество',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Цена',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${numberFormat.format(item.price)} ₸',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок и поиск
          Container(
            padding: EdgeInsets.all(padding),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Товары',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: isMobile ? 24 : 28,
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Управление товарами и запчастями',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isMobile)
                      Row(
                        children: [
                          IconButton(
                            icon: Stack(
                              children: [
                                const Icon(Icons.filter_list),
                                if (activeFiltersCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        activeFiltersCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: _showFiltersDialog,
                            tooltip: 'Фильтры',
                          ),
                          IconButton(
                            icon: const Icon(Icons.print),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PrinterSettingsScreen(),
                                ),
                              );
                            },
                            tooltip: 'Настройки принтера',
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showItemDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить товар'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          IconButton(
                            icon: Stack(
                              children: [
                                const Icon(Icons.filter_list),
                                if (activeFiltersCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        activeFiltersCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: _showFiltersDialog,
                            tooltip: 'Фильтры',
                          ),
                          IconButton(
                            icon: const Icon(Icons.print),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PrinterSettingsScreen(),
                                ),
                              );
                            },
                            tooltip: 'Настройки принтера',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _showItemDialog(context),
                            tooltip: 'Добавить товар',
                          ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию или артикулу...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isMobile ? 12 : 16,
                          ),
                        ),
                        onChanged: _filterItems,
                      ),
                    ),
                  ],
                ),
                // Активные фильтры
                if (activeFiltersCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (activeFilters['category'] != null)
                        Chip(
                          label: Text('Категория: ${activeFilters['category']}'),
                          onDeleted: () {
                            setState(() => activeFilters.remove('category'));
                            _applyFilters(activeFilters);
                          },
                        ),
                      if (activeFilters['condition'] != null)
                        Chip(
                          label: Text('Состояние: ${_getConditionLabel(activeFilters['condition'])}'),
                          onDeleted: () {
                            setState(() => activeFilters.remove('condition'));
                            _applyFilters(activeFilters);
                          },
                        ),
                      if (activeFilters['warehouseId'] != null)
                        Chip(
                          label: Text('Склад: ${_getWarehouseName(activeFilters['warehouseId'])}'),
                          onDeleted: () {
                            setState(() => activeFilters.remove('warehouseId'));
                            _applyFilters(activeFilters);
                          },
                        ),
                      if (activeFilters['inStock'] != null)
                        Chip(
                          label: Text(activeFilters['inStock'] == true ? 'В наличии' : 'Нет в наличии'),
                          onDeleted: () {
                            setState(() => activeFilters.remove('inStock'));
                            _applyFilters(activeFilters);
                          },
                        ),
                      if (activeFilters['minPrice'] != null || activeFilters['maxPrice'] != null)
                        Chip(
                          label: Text('Цена: ${activeFilters['minPrice'] ?? 0} - ${activeFilters['maxPrice'] ?? '∞'} ₸'),
                          onDeleted: () {
                            setState(() {
                              activeFilters.remove('minPrice');
                              activeFilters.remove('maxPrice');
                            });
                            _applyFilters(activeFilters);
                          },
                        ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            activeFilters.clear();
                            activeFiltersCount = 0;
                          });
                          _loadItems();
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Сбросить все'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Список товаров
          Expanded(
            child: _buildItemsList(isMobile: isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, List<ItemModel> items) {
    final numberFormat = NumberFormat('#,###', 'ru_RU');

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
                  flex: 3,
                  child: Text(
                    'Название',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Артикул',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Категория',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Количество',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Цена',
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
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < items.length - 1
                          ? const BorderSide(color: AppTheme.borderColor)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.name ?? 'Без названия',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(item.sku ?? '-'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(item.category ?? '-'),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.quantity > 10
                                ? AppTheme.successGradient.colors[0]
                                    .withOpacity(0.1)
                                : item.quantity > 0
                                    ? AppTheme.warningGradient.colors[0]
                                        .withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              color: item.quantity > 10
                                  ? AppTheme.successGradient.colors[0]
                                  : item.quantity > 0
                                      ? AppTheme.warningGradient.colors[0]
                                      : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${numberFormat.format(item.price)} ₸',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editItem(context, item),
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _showDeleteDialog(context, item),
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

  void _showItemDialog(BuildContext context, {ItemModel? item}) {
    final isEdit = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final skuController = TextEditingController(text: item?.sku ?? '');
    final priceController =
        TextEditingController(text: item?.price.toString() ?? '');
    final quantityController =
        TextEditingController(text: item?.quantity.toString() ?? '');
    final descriptionController =
        TextEditingController(text: item?.description ?? '');
    final warehouseCellController =
        TextEditingController(text: item?.warehouseCell ?? '');

    // Категории товаров (как в B2C, но без "Все")
    final List<String> categories = [
      'Двигатель',
      'Трансмиссия',
      'Тормозная система',
      'Подвеска',
      'Электрика',
      'Кузов',
      'Салон',
      'Оптика',
      'Фильтры',
      'Расходники',
    ];
    
    String? selectedCategory = item?.category;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Редактировать товар' : 'Добавить товар'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: skuController,
                    decoration: const InputDecoration(
                      labelText: 'Артикул',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Выберите категорию'),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Цена *',
                            border: OutlineInputBorder(),
                            suffixText: '₸',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Количество *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: warehouseCellController,
                    decoration: const InputDecoration(
                      labelText: 'Ячейка склада',
                      hintText: 'Например: A-1-2',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Укажите название товара')),
                );
                return;
              }

              final data = {
                'name': nameController.text,
                'sku': skuController.text.isEmpty ? null : skuController.text,
                'category': selectedCategory,
                'price': double.tryParse(priceController.text) ?? 0,
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'description': descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
                'warehouseCell': warehouseCellController.text.isEmpty
                    ? null
                    : warehouseCellController.text.trim(),
                'condition': 'new',
              };

              try {
                if (isEdit) {
                  await dio.put('/api/items/${item!.id}', data: data);
                } else {
                  await dio.post('/api/items', data: data);
                }

                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  _loadItems();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isEdit ? 'Товар обновлен' : 'Товар добавлен'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Добавить'),
          ),
        ],
      ),
    ),
    );
  }

  void _showDeleteDialog(BuildContext context, ItemModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('Вы уверены что хотите удалить "${item.name ?? 'Без названия'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await dio.delete('/api/items/${item.id}');
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  _loadItems();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Товар удален')),
                  );
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

  Future<void> _editItem(BuildContext context, ItemModel item) async {
    final result = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(
        builder: (context) => ItemEditScreen(item: item),
      ),
    );

    if (result != null) {
      // Обновляем список товаров после редактирования
      _loadItems();
    }
  }

  String _getConditionLabel(String condition) {
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

  String _getWarehouseName(String warehouseId) {
    final warehouse = warehouses.firstWhere(
      (w) => w.id == warehouseId,
      orElse: () => Warehouse(
        id: warehouseId,
        name: 'Неизвестный склад',
        organizationId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return warehouse.name;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
