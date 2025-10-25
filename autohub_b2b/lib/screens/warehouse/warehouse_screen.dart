import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/screens/warehouse/item_edit_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  List<ItemModel> items = [];
  List<ItemModel> filteredItems = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await dio.get('/api/items');
      final List<dynamic> data = response.data;

      setState(() {
        items = data.map((json) => ItemModel.fromJson(json)).toList();
        filteredItems = items;
        isLoading = false;
      });
    } catch (e) {
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

  Widget _buildItemsList() {
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

    return _buildItemsTable(context, filteredItems);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок и поиск
          Container(
            padding: const EdgeInsets.all(24),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Склад',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Управление товарами и запчастями',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showItemDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить товар'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                        ),
                        onChanged: _filterItems,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Показать фильтры
                      },
                      icon: const Icon(Icons.filter_list),
                      label: const Text('Фильтры'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Список товаров
          Expanded(
            child: _buildItemsList(),
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
    final categoryController = TextEditingController(text: item?.category ?? '');
    final priceController =
        TextEditingController(text: item?.price.toString() ?? '');
    final quantityController =
        TextEditingController(text: item?.quantity.toString() ?? '');
    final descriptionController =
        TextEditingController(text: item?.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
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
                'category': categoryController.text.isEmpty
                    ? 'Общее'
                    : categoryController.text,
                'price': double.tryParse(priceController.text) ?? 0,
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'description': descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
