import 'package:flutter/material.dart';
import '../../models/warehouse_model.dart';
import '../../services/warehouse_service.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({Key? key}) : super(key: key);

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final WarehouseService _warehouseService = WarehouseService();
  List<Warehouse> _warehouses = [];
  Map<String, int> _itemsCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _isLoading = true);
    try {
      final warehouses = await _warehouseService.getWarehouses();
      final counts = <String, int>{};
      
      for (var warehouse in warehouses) {
        final count = await _warehouseService.getItemsCount(warehouse.id);
        counts[warehouse.id] = count;
      }

      setState(() {
        _warehouses = warehouses;
        _itemsCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки складов: $e')),
        );
      }
    }
  }

  void _showWarehouseDialog([Warehouse? warehouse]) {
    final nameController = TextEditingController(text: warehouse?.name ?? '');
    final addressController = TextEditingController(text: warehouse?.address ?? '');
    final phoneController = TextEditingController(text: warehouse?.phone ?? '');
    final contactController = TextEditingController(text: warehouse?.contactPerson ?? '');
    bool isActive = warehouse?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          
          return AlertDialog(
            title: Text(warehouse == null ? 'Добавить склад' : 'Редактировать склад'),
            content: SizedBox(
              width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название склада *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Адрес',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Контактное лицо',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Активен'),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите название склада')),
                    );
                    return;
                  }

                  try {
                    if (warehouse == null) {
                      await _warehouseService.createWarehouse(
                        name: nameController.text,
                        address: addressController.text.isEmpty ? null : addressController.text,
                        phone: phoneController.text.isEmpty ? null : phoneController.text,
                        contactPerson: contactController.text.isEmpty ? null : contactController.text,
                        isActive: isActive,
                      );
                    } else {
                      await _warehouseService.updateWarehouse(
                        warehouse.id,
                        name: nameController.text,
                        address: addressController.text.isEmpty ? null : addressController.text,
                        phone: phoneController.text.isEmpty ? null : phoneController.text,
                        contactPerson: contactController.text.isEmpty ? null : contactController.text,
                        isActive: isActive,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadWarehouses();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
                child: Text(warehouse == null ? 'Создать' : 'Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteWarehouse(Warehouse warehouse) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление склада'),
        content: Text('Вы уверены, что хотите удалить склад "${warehouse.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _warehouseService.deleteWarehouse(warehouse.id);
        _loadWarehouses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Склады'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWarehouses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _warehouses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет складов',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Нажмите + чтобы добавить первый склад'),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 768;

                    if (isMobile) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _warehouses.length,
                        itemBuilder: (context, index) {
                          final warehouse = _warehouses[index];
                          final itemsCount = _itemsCounts[warehouse.id] ?? 0;

                          return Card(
                            child: ListTile(
                              title: Text(warehouse.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (warehouse.address != null)
                                    Text('Адрес: ${warehouse.address}'),
                                  Text('Товаров: $itemsCount'),
                                  if (!warehouse.isActive)
                                    const Text(
                                      'Неактивен',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showWarehouseDialog(warehouse),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deleteWarehouse(warehouse),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    // Desktop layout
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Название')),
                          DataColumn(label: Text('Адрес')),
                          DataColumn(label: Text('Телефон')),
                          DataColumn(label: Text('Контакт')),
                          DataColumn(label: Text('Товаров')),
                          DataColumn(label: Text('Статус')),
                          DataColumn(label: Text('Действия')),
                        ],
                        rows: _warehouses.map((warehouse) {
                          final itemsCount = _itemsCounts[warehouse.id] ?? 0;

                          return DataRow(
                            cells: [
                              DataCell(Text(warehouse.name)),
                              DataCell(Text(warehouse.address ?? '-')),
                              DataCell(Text(warehouse.phone ?? '-')),
                              DataCell(Text(warehouse.contactPerson ?? '-')),
                              DataCell(Text(itemsCount.toString())),
                              DataCell(
                                warehouse.isActive
                                    ? const Chip(
                                        label: Text('Активен'),
                                        backgroundColor: Colors.green,
                                      )
                                    : const Chip(
                                        label: Text('Неактивен'),
                                        backgroundColor: Colors.red,
                                      ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _showWarehouseDialog(warehouse),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      color: Colors.red,
                                      onPressed: () => _deleteWarehouse(warehouse),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWarehouseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

