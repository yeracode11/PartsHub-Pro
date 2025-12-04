import 'package:flutter/material.dart';
import '../../models/warehouse_model.dart';
import '../../services/warehouse_service.dart';
import '../../services/items_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() => _isLoading = true);
    try {
      final transfers = await _warehouseService.getTransfers();
      setState(() {
        _transfers = transfers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  void _showCreateTransferDialog() async {
    try {
      final warehouses = await _warehouseService.getWarehouses();
      final items = await _itemsService.getItems();

      if (!mounted) return;

      String? fromWarehouseId;
      String? toWarehouseId;
      int? itemId;
      int quantity = 1;
      final notesController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final isMobile = MediaQuery.of(context).size.width < 600;

            return AlertDialog(
              title: const Text('Создать перемещение'),
              content: SizedBox(
                width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: fromWarehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Склад источник *',
                          border: OutlineInputBorder(),
                        ),
                        items: warehouses.map((w) {
                          return DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => fromWarehouseId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: toWarehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Склад назначения *',
                          border: OutlineInputBorder(),
                        ),
                        items: warehouses
                            .where((w) => w.id != fromWarehouseId)
                            .map((w) {
                          return DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => toWarehouseId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: itemId,
                        decoration: const InputDecoration(
                          labelText: 'Товар *',
                          border: OutlineInputBorder(),
                        ),
                        items: items.map((item) {
                          return DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => itemId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: quantity.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Количество *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setDialogState(() => quantity = int.tryParse(value) ?? 1);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Примечание',
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (fromWarehouseId == null || toWarehouseId == null || itemId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните все обязательные поля')),
                      );
                      return;
                    }

                    try {
                      await _warehouseService.createTransfer(
                        fromWarehouseId: fromWarehouseId!,
                        toWarehouseId: toWarehouseId!,
                        itemId: itemId!,
                        quantity: quantity,
                        notes: notesController.text.isEmpty ? null : notesController.text,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        _loadTransfers();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        ),
      );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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

