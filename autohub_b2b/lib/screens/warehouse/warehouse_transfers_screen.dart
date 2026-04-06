import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/warehouse_model.dart';
import '../../models/item_model.dart';
import '../../widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import '../../services/warehouse_service.dart';
import '../../services/items_service.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';

class WarehouseTransfersScreen extends StatefulWidget {
  const WarehouseTransfersScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseTransfersScreen> createState() => _WarehouseTransfersScreenState();
}

class _WarehouseTransfersScreenState extends State<WarehouseTransfersScreen> {
  final WarehouseService _warehouseService = WarehouseService();
  final ItemsService _itemsService = ItemsService();
  List<WarehouseTransfer> _transfers = [];
  bool _isLoading = true;
  bool _isForbidden = false;
  String? _forbiddenMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() {
      _isLoading = true;
      _isForbidden = false;
      _isOffline = false;
    });
    try {
      final transfers = await _warehouseService.getTransfers();
      setState(() {
        _transfers = transfers;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        setState(() {
          _isForbidden = true;
          _forbiddenMessage = (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к разделу «Перемещения». Войдите под владельцем или менеджером.';
          _isLoading = false;
        });
      } else if (isNetworkError(e)) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки: $e')),
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
            SnackBar(content: Text('Ошибка загрузки: $e')),
          );
        }
      }
    }
  }

  void _showCreateTransferDialog() async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    try {
      final warehouses = await _warehouseService.getWarehouses();
      final items = await _itemsService.getItems();

      if (!mounted) return;

      final isMobile = MediaQuery.of(context).size.width < 768;
      final formWidget = _TransferFormDialog(
        warehouses: warehouses,
        items: items,
        warehouseService: _warehouseService,
        onSuccess: () {
          Navigator.pop(context);
          _loadTransfers();
        },
      );

      if (isMobile) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => formWidget),
        );
      } else {
        showDialog(context: context, builder: (_) => formWidget);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(WarehouseTransfer transfer, TransferStatus newStatus) async {
    try {
      await _warehouseService.updateTransferStatus(transfer.id, newStatus);
      _loadTransfers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Перемещения товаров'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransfers,
          ),
        ],
      ),
      body: _isForbidden
          ? UnauthorizedPlaceholder(message: _forbiddenMessage)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isOffline
              ? OfflinePlaceholder(onRetry: _loadTransfers)
              : _transfers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Нет перемещений'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transfers.length,
                  itemBuilder: (context, index) {
                    final transfer = _transfers[index];

                    return Card(
                      child: ExpansionTile(
                        leading: Icon(
                          _getStatusIcon(transfer.status),
                          color: _getStatusColor(transfer.status),
                        ),
                        title: Text(
                          '${transfer.fromWarehouse?.name ?? "?"} → ${transfer.toWarehouse?.name ?? "?"}',
                        ),
                        subtitle: Text(
                          'Товар: ${transfer.item?['name'] ?? "ID: ${transfer.itemId}"}\nКол-во: ${transfer.quantity}',
                        ),
                        trailing: Chip(
                          label: Text(transfer.status.getDisplayName()),
                          backgroundColor: _getStatusColor(transfer.status).withOpacity(0.2),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (transfer.notes != null) ...[
                                  const Text('Примечание:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(transfer.notes!),
                                  const SizedBox(height: 8),
                                ],
                                Text('Создано: ${_formatDate(transfer.createdAt)}'),
                                if (transfer.completedAt != null)
                                  Text('Завершено: ${_formatDate(transfer.completedAt!)}'),
                                const SizedBox(height: 16),
                                if (transfer.status == TransferStatus.draft)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(transfer, TransferStatus.inTransit),
                                        icon: const Icon(Icons.local_shipping),
                                        label: const Text('В путь'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(transfer, TransferStatus.completed),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Завершить'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (transfer.status == TransferStatus.inTransit)
                                  ElevatedButton.icon(
                                    onPressed: () => _updateStatus(transfer, TransferStatus.completed),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Завершить'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTransferDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.draft:
        return Icons.edit;
      case TransferStatus.inTransit:
        return Icons.local_shipping;
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.draft:
        return Colors.grey;
      case TransferStatus.inTransit:
        return Colors.orange;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _TransferFormDialog extends StatefulWidget {
  final List<Warehouse> warehouses;
  final List<ItemModel> items;
  final WarehouseService warehouseService;
  final VoidCallback onSuccess;

  const _TransferFormDialog({
    required this.warehouses,
    required this.items,
    required this.warehouseService,
    required this.onSuccess,
  });

  @override
  State<_TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends State<_TransferFormDialog> {
  String? _fromWarehouseId;
  String? _toWarehouseId;
  int? _itemId;
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_fromWarehouseId == null || _toWarehouseId == null || _itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля')),
      );
      return;
    }
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите корректное количество')),
      );
      return;
    }
    try {
      await widget.warehouseService.createTransfer(
        fromWarehouseId: _fromWarehouseId!,
        toWarehouseId: _toWarehouseId!,
        itemId: _itemId!,
        quantity: quantity,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      if (mounted) {
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Перемещение создано')),
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
        DropdownButtonFormField<String>(
          value: _fromWarehouseId,
          decoration: const InputDecoration(
            labelText: 'Склад источник *',
            border: OutlineInputBorder(),
          ),
          items: widget.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
          onChanged: (v) => setState(() {
            _fromWarehouseId = v;
            if (_toWarehouseId == v) _toWarehouseId = null;
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _toWarehouseId,
          decoration: const InputDecoration(
            labelText: 'Склад назначения *',
            border: OutlineInputBorder(),
          ),
          items: widget.warehouses
              .where((w) => w.id != _fromWarehouseId)
              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
              .toList(),
          onChanged: (v) => setState(() => _toWarehouseId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _itemId,
          decoration: const InputDecoration(
            labelText: 'Товар *',
            border: OutlineInputBorder(),
          ),
          items: widget.items.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name ?? 'Без названия'))).toList(),
          onChanged: (v) => setState(() => _itemId = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Количество *',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Примечание',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
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
          title: const Text('Создать перемещение'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          actions: [
            FilledButton(onPressed: _save, child: const Text('Создать')),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildFormContent(),
        ),
      );
    }
    return AlertDialog(
      title: const Text('Создать перемещение'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(child: _buildFormContent()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(onPressed: _save, child: const Text('Создать')),
      ],
    );
  }
}

