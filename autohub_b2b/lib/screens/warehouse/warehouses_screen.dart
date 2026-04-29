import 'package:flutter/material.dart';
import '../../models/warehouse_model.dart';
import '../../services/warehouse_service.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:dio/dio.dart';

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
  bool _isForbidden = false;
  String? _forbiddenMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoading = true;
      _isForbidden = false;
      _forbiddenMessage = null;
      _isOffline = false;
    });
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        if (mounted) {
          setState(() {
            _isForbidden = true;
            _isLoading = false;
            _forbiddenMessage =
                (e.response?.data is Map<String, dynamic> ? (e.response?.data['message'] as String?) : null) ??
                    'У вас нет доступа к разделу "Склады". Войдите под владельцем или менеджером.';
          });
        }
      } else if (isNetworkError(e)) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userFacingApiMessage(e))),
          );
        }
      }
    } catch (e) {
      if (isNetworkError(e)) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userFacingApiMessage(e))),
          );
        }
      }
    }
  }

  Future<void> _showWarehouseDialog([Warehouse? warehouse]) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final formWidget = _WarehouseFormDialog(
      warehouse: warehouse,
      warehouseService: _warehouseService,
      onSuccess: () {
        Navigator.pop(context);
        _loadWarehouses();
      },
    );
    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => formWidget),
      );
    } else {
      showDialog(context: context, builder: (_) => formWidget);
    }
  }

  Future<void> _deleteWarehouse(Warehouse warehouse) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final confirm = await DialogHelper.showConfirmSimple(
      context: context,
      title: 'Удаление склада',
      message: 'Вы уверены, что хотите удалить склад "${warehouse.name}"?',
      confirmText: 'Удалить',
      isDestructive: true,
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
    if (_isForbidden) {
      return Scaffold(
        body: UnauthorizedPlaceholder(
          message: _forbiddenMessage ??
              'У вас нет доступа к разделу "Склады". Войдите под владельцем или менеджером.',
        ),
      );
    }

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
          : _isOffline
              ? OfflinePlaceholder(onRetry: _loadWarehouses)
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

class _WarehouseFormDialog extends StatefulWidget {
  final Warehouse? warehouse;
  final WarehouseService warehouseService;
  final VoidCallback onSuccess;

  const _WarehouseFormDialog({
    this.warehouse,
    required this.warehouseService,
    required this.onSuccess,
  });

  @override
  State<_WarehouseFormDialog> createState() => _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends State<_WarehouseFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _contactController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    _nameController = TextEditingController(text: w?.name ?? '');
    _addressController = TextEditingController(text: w?.address ?? '');
    _phoneController = TextEditingController(text: w?.phone ?? '');
    _contactController = TextEditingController(text: w?.contactPerson ?? '');
    _isActive = w?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название склада')),
      );
      return;
    }
    try {
      if (widget.warehouse == null) {
        await widget.warehouseService.createWarehouse(
          name: _nameController.text,
          address: _addressController.text.isEmpty ? null : _addressController.text,
          phone: _phoneController.text.isEmpty ? null : _phoneController.text,
          contactPerson: _contactController.text.isEmpty ? null : _contactController.text,
          isActive: _isActive,
        );
      } else {
        await widget.warehouseService.updateWarehouse(
          widget.warehouse!.id,
          name: _nameController.text,
          address: _addressController.text.isEmpty ? null : _addressController.text,
          phone: _phoneController.text.isEmpty ? null : _phoneController.text,
          contactPerson: _contactController.text.isEmpty ? null : _contactController.text,
          isActive: _isActive,
        );
      }
      if (mounted) {
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.warehouse == null ? 'Склад создан' : 'Склад обновлен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Название склада *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(labelText: 'Адрес', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contactController,
          decoration: const InputDecoration(labelText: 'Контактное лицо', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Активен'),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.warehouse != null;
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Редактировать склад' : 'Добавить склад'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          actions: [
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildFormContent(),
        ),
      );
    }
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать склад' : 'Добавить склад'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(child: _buildFormContent()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(onPressed: _save, child: Text(isEdit ? 'Сохранить' : 'Создать')),
      ],
    );
  }
}

