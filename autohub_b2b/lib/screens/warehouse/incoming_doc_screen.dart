import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/models/incoming_item_model.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/incoming_api_service.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';
import 'package:autohub_b2b/screens/warehouse/incoming_add_item_screen.dart';

class IncomingDocScreen extends StatefulWidget {
  final String? docId;

  const IncomingDocScreen({super.key, this.docId});

  @override
  State<IncomingDocScreen> createState() => _IncomingDocScreenState();
}

class _IncomingDocScreenState extends State<IncomingDocScreen> {
  final IncomingApiService _apiService = IncomingApiService(ApiClient());
  final ApiClient _apiClient = ApiClient();
  final ThermalPrinterService _printer = ThermalPrinterService();
  
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _notesController = TextEditingController();

  IncomingDocModel? _document;
  List<CustomerModel> _customers = [];
  String? _selectedSupplierId;
  IncomingDocType _selectedType = IncomingDocType.newParts;
  bool _isLoading = false;
  bool _isLoadingDoc = true;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCustomers();
    if (widget.docId != null) {
      _loadDocument();
    } else {
      _isLoadingDoc = false;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _supplierNameController.dispose();
    _warehouseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    if (widget.docId == null) return;

    setState(() {
      _isLoadingDoc = true;
    });

    try {
      final doc = await _apiService.getDocument(widget.docId!);
      setState(() {
        _document = doc;
        _dateController.text = DateFormat('yyyy-MM-dd').format(doc.date);
        _selectedSupplierId = doc.supplierId;
        _supplierNameController.text = doc.supplierName ?? '';
        _selectedType = doc.type;
        _warehouseController.text = doc.warehouse ?? '';
        _notesController.text = doc.notes ?? '';
        _isLoadingDoc = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDoc = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final response = await _apiClient.dio.get('/api/customers');
      final List<dynamic> data = response.data;
      setState(() {
        _customers = data
            .map((json) => CustomerModel.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Error loading customers: $e');
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = <String, dynamic>{
        'date': _dateController.text,
        'type': _selectedType == IncomingDocType.usedParts
            ? 'used_parts'
            : _selectedType == IncomingDocType.newParts
                ? 'new_parts'
                : 'own_production',
      };

      // Добавляем supplierId только если он выбран
      if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
        data['supplierId'] = _selectedSupplierId;
      }

      // Добавляем supplierName только если он указан и supplierId не выбран
      if (_selectedSupplierId == null && _supplierNameController.text.isNotEmpty) {
        data['supplierName'] = _supplierNameController.text;
      }

      // Добавляем остальные поля только если они не пустые
      if (_warehouseController.text.isNotEmpty) {
        data['warehouse'] = _warehouseController.text;
      }

      if (_notesController.text.isNotEmpty) {
        data['notes'] = _notesController.text;
      }

      if (_document == null) {
        // Создание новой накладной
        final doc = await _apiService.createDocument(data);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Обновление существующей
        await _apiService.updateDocument(_document!.id, data);
        await _loadDocument();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Накладная обновлена'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processDocument() async {
    if (_document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Провести накладную?'),
        content: const Text(
          'После проведения накладной остатки на складе будут обновлены. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Провести'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.processDocument(_document!.id);
      await _loadDocument();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Накладная проведена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка проведения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDoc) {
      return Scaffold(
        appBar: AppBar(title: const Text('Приходная накладная')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_document == null
            ? 'Новая накладная'
            : 'Накладная ${_document!.docNumber}'),
        actions: [
          if (_document != null &&
              _document!.status == IncomingDocStatus.done)
            IconButton(
              icon: const Icon(Icons.check_circle),
              color: Colors.green,
              onPressed: null,
              tooltip: 'Проведена',
            ),
          if (_document != null &&
              _document!.status == IncomingDocStatus.draft)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _processDocument,
              tooltip: 'Провести',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveDocument,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Основная информация
                    _buildDocumentInfo(),
                    const SizedBox(height: 24),

                    // Позиции
                    if (_document != null) _buildItemsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocumentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Основная информация',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Дата
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Дата *',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              readOnly: _document?.status == IncomingDocStatus.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Укажите дату';
                }
                return null;
              },
              onTap: _document?.status == IncomingDocStatus.done
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        _dateController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Тип прихода
            DropdownButtonFormField<IncomingDocType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Тип прихода *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: IncomingDocType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: _document?.status == IncomingDocStatus.done
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Поставщик из справочника
            DropdownButtonFormField<String?>(
              value: _selectedSupplierId,
              decoration: const InputDecoration(
                labelText: 'Поставщик (из справочника)',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Не выбран'),
                ),
                ..._customers.map((customer) {
                  return DropdownMenuItem<String?>(
                    value: customer.id.toString(),
                    child: Text(customer.name),
                  );
                }),
              ],
              onChanged: _document?.status == IncomingDocStatus.done
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSupplierId = value;
                        if (value != null) {
                          _supplierNameController.clear();
                        }
                      });
                    },
            ),
            const SizedBox(height: 16),

            // Или название поставщика
            TextFormField(
              controller: _supplierNameController,
              decoration: const InputDecoration(
                labelText: 'Или название поставщика',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                hintText: 'Если поставщик не в справочнике',
              ),
              readOnly: _document?.status == IncomingDocStatus.done ||
                  _selectedSupplierId != null,
              enabled: _selectedSupplierId == null &&
                  _document?.status != IncomingDocStatus.done,
            ),
            const SizedBox(height: 16),

            // Склад
            TextFormField(
              controller: _warehouseController,
              decoration: const InputDecoration(
                labelText: 'Склад',
                prefixIcon: Icon(Icons.warehouse),
                border: OutlineInputBorder(),
              ),
              readOnly: _document?.status == IncomingDocStatus.done,
            ),
            const SizedBox(height: 16),

            // Примечание
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              readOnly: _document?.status == IncomingDocStatus.done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final items = _document?.items ?? [];
    final numberFormat = NumberFormat('#,###', 'ru_RU');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                if (isMobile) {
                  // На мобильных устройствах размещаем вертикально
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Позиции (${items.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_document!.status == IncomingDocStatus.draft) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => IncomingAddItemScreen(
                                        docId: _document!.id,
                                        docType: _selectedType,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadDocument();
                                  }
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Добавить'),
                              ),
                            ),
                            if (items.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _printAllLabels(items),
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text('Печать'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  );
                }
                
                // На десктопе оставляем горизонтально
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Позиции (${items.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_document!.status == IncomingDocStatus.draft)
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => IncomingAddItemScreen(
                                    docId: _document!.id,
                                    docType: _selectedType,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadDocument();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить позицию'),
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _printAllLabels(items),
                              icon: const Icon(Icons.print),
                              label: const Text('Печать всех наклеек'),
                            ),
                          ],
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет позиций',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) => _buildItemCard(item)),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Итого:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${numberFormat.format(_document!.totalAmount)} ₸',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(IncomingItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.category != null) Text('Категория: ${item.category}'),
            if (item.carBrand != null)
              Text('Авто: ${item.carBrand} ${item.carModel ?? ''}'),
            Text('Кол-во: ${item.quantity} × ${item.purchasePrice} ₸'),
            if (item.warehouseCell != null)
              Text('Ячейка: ${item.warehouseCell}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка печати наклейки
            IconButton(
              icon: const Icon(Icons.print, color: AppTheme.primaryColor),
              onPressed: () => _printLabel(item),
              tooltip: 'Печать наклейки',
            ),
            // Кнопка удаления (только для черновиков)
            if (_document?.status == IncomingDocStatus.draft)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Удалить позицию?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Отмена'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await _apiService.removeItem(item.id);
                      _loadDocument();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Печать наклейки для одного товара
  Future<void> _printLabel(IncomingItemModel item) async {
    try {
      // Показываем диалог подключения принтера
      if (!_printer.isConnected) {
        final shouldConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Подключение принтера'),
            content: const Text(
              'Принтер не подключен. Хотите подключиться к USB принтеру?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Подключить'),
              ),
            ],
          ),
        );

        if (shouldConnect != true) return;

        // Показываем индикатор загрузки
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final connected = await _printer.connectUSB();
        
        if (mounted) {
          Navigator.of(context).pop(); // Закрываем индикатор загрузки
        }

        if (!connected) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось подключиться к принтеру. Проверьте подключение.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Показываем индикатор печати
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Печать наклейки...'),
              ],
            ),
          ),
        );
      }

      final success = await _printer.printLabel(
        itemName: item.name,
        sku: item.sku,
        price: item.purchasePrice,
        warehouseCell: item.warehouseCell,
        quantity: item.quantity,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор печати
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Напечатано наклеек: ${item.quantity}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка печати. Проверьте подключение принтера.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор, если открыт
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка печати: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Печать наклеек для всех товаров в накладной
  Future<void> _printAllLabels(List<IncomingItemModel> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Печать всех наклеек'),
        content: Text(
          'Будет напечатано наклеек для ${items.length} позиций. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Печать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Показываем диалог подключения принтера
      if (!_printer.isConnected) {
        final shouldConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Подключение принтера'),
            content: const Text(
              'Принтер не подключен. Хотите подключиться к USB принтеру?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Подключить'),
              ),
            ],
          ),
        );

        if (shouldConnect != true) return;

        // Показываем индикатор загрузки
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final connected = await _printer.connectUSB();
        
        if (mounted) {
          Navigator.of(context).pop(); // Закрываем индикатор загрузки
        }

        if (!connected) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось подключиться к принтеру. Проверьте подключение.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Показываем индикатор печати
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              int printed = 0;
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Печать наклеек: $printed / ${items.length}'),
                  ],
                ),
              );
            },
          ),
        );
      }

      int totalPrinted = 0;
      for (final item in items) {
        final success = await _printer.printLabel(
          itemName: item.name,
          sku: item.sku,
          price: item.purchasePrice,
          warehouseCell: item.warehouseCell,
          quantity: item.quantity,
        );
        
        if (success) {
          totalPrinted += item.quantity;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор печати
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Напечатано наклеек: $totalPrinted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор, если открыт
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка печати: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

