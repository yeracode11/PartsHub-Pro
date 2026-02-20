import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/incoming_api_service.dart';
import 'package:autohub_b2b/services/hardware/barcode_scanner_service.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';

class IncomingAddItemScreen extends StatefulWidget {
  final String docId;
  final IncomingDocType docType;

  const IncomingAddItemScreen({
    super.key,
    required this.docId,
    required this.docType,
  });

  @override
  State<IncomingAddItemScreen> createState() => _IncomingAddItemScreenState();
}

class _IncomingAddItemScreenState extends State<IncomingAddItemScreen> {
  final IncomingApiService _apiService = IncomingApiService(ApiClient());
  final ApiClient _apiClient = ApiClient();
  final BarcodeScannerService _barcodeScanner = BarcodeScannerService();
  final ThermalPrinterService _printer = ThermalPrinterService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _vinController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _warehouseCellController = TextEditingController();
  final _skuController = TextEditingController();

  List<ItemModel> _items = [];
  ItemModel? _selectedItem;
  String _selectedCondition = 'new';
  bool _isLoading = false;
  bool _isSearchingItems = false;
  bool _isSearchingByBarcode = false;
  final FocusNode _skuFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.docType == IncomingDocType.newParts) {
      _loadItems();
    }
    
    // Настройка обработчика сканера штрих-кодов
    _barcodeScanner.onBarcodeScanned = _onBarcodeScanned;
    
    // Автофокус на поле SKU для удобства сканирования
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _skuFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _vinController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _warehouseCellController.dispose();
    _skuController.dispose();
    _skuFocusNode.dispose();
    _barcodeScanner.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isSearchingItems = true;
    });

    try {
      final response = await _apiClient.dio.get('/api/items');
      final List<dynamic> data = response.data;
      setState(() {
        _items = data
            .map((json) => ItemModel.fromJson(json as Map<String, dynamic>))
            .toList();
        _isSearchingItems = false;
      });
    } catch (e) {
      setState(() {
        _isSearchingItems = false;
      });
    }
  }

  void _onItemSelected(ItemModel? item) {
    setState(() {
      _selectedItem = item;
      if (item != null) {
        _nameController.text = item.name;
        _categoryController.text = item.category ?? '';
        _skuController.text = item.sku ?? '';
        _selectedCondition = item.condition;
        _priceController.text = item.price.toStringAsFixed(2);
      }
    });
  }

  /// Обработка отсканированного штрих-кода
  Future<void> _onBarcodeScanned(String barcode) async {
    if (widget.docType != IncomingDocType.newParts) return;
    
    setState(() {
      _isSearchingByBarcode = true;
    });

    try {
      // Ищем товар по SKU/штрих-коду
      final foundItem = _items.firstWhere(
        (item) => item.sku?.toLowerCase() == barcode.toLowerCase(),
        orElse: () => ItemModel(
          name: '',
          price: 0,
          quantity: 0,
          condition: 'new',
        ),
      );

      if (foundItem.name.isNotEmpty) {
        // Товар найден - заполняем форму
        _onItemSelected(foundItem);
        
        // Воспроизводим звуковой сигнал (опционально)
        await _barcodeScanner.playBeep();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Товар найден: ${foundItem.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Товар не найден - заполняем только SKU
        _skuController.text = barcode;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Товар с артикулом "$barcode" не найден. Заполните данные вручную.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      _skuController.text = barcode;
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingByBarcode = false;
        });
      }
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'itemId': _selectedItem?.id,
        'name': _nameController.text.trim(),
        'category': _categoryController.text.isEmpty
            ? null
            : _categoryController.text.trim(),
        'carBrand': _carBrandController.text.isEmpty
            ? null
            : _carBrandController.text.trim(),
        'carModel': _carModelController.text.isEmpty
            ? null
            : _carModelController.text.trim(),
        'vin': _vinController.text.isEmpty ? null : _vinController.text.trim(),
        'condition': _selectedCondition,
        'quantity': int.parse(_quantityController.text),
        'purchasePrice': double.parse(_priceController.text),
        'warehouseCell': _warehouseCellController.text.isEmpty
            ? null
            : _warehouseCellController.text.trim(),
        'sku': _skuController.text.isEmpty ? null : _skuController.text.trim(),
      };

      await _apiService.addItem(widget.docId, data);

      if (mounted) {
        // Предлагаем напечатать наклейку
        final printLabel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Товар добавлен'),
            content: const Text('Хотите напечатать наклейку для этого товара?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Пропустить'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Печать'),
              ),
            ],
          ),
        );

        if (printLabel == true) {
          await _printLabel(
            itemName: _nameController.text.trim(),
            sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
            price: double.parse(_priceController.text),
            warehouseCell: _warehouseCellController.text.trim().isEmpty 
                ? null 
                : _warehouseCellController.text.trim(),
            quantity: int.parse(_quantityController.text),
          );
        }

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка добавления: $e'),
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
    final isUsedParts = widget.docType == IncomingDocType.usedParts;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Добавить позицию'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveItem,
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
                    // Выбор товара (для новых запчастей)
                    if (!isUsedParts) ...[
                      _buildItemSelector(),
                      const SizedBox(height: 24),
                    ],

                    // Основная информация
                    _buildBasicInfo(isUsedParts),
                    const SizedBox(height: 24),

                    // Информация об авто (для Б/У)
                    if (isUsedParts) ...[
                      _buildCarInfo(),
                      const SizedBox(height: 24),
                    ],

                    // Цена и количество
                    _buildPriceAndQuantity(),
                    const SizedBox(height: 24),

                    // Ячейка хранения
                    _buildWarehouseCell(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildItemSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выбор товара',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_isSearchingItems)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<ItemModel?>(
                value: _selectedItem,
                decoration: const InputDecoration(
                  labelText: 'Товар из каталога',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  hintText: 'Выберите товар или введите вручную',
                ),
                items: [
                  const DropdownMenuItem<ItemModel?>(
                    value: null,
                    child: Text('Ввести вручную'),
                  ),
                  ..._items.map((item) {
                    return DropdownMenuItem<ItemModel?>(
                      value: item,
                      child: Text('${item.name} (${item.sku ?? 'нет артикула'})'),
                    );
                  }),
                ],
                onChanged: _onItemSelected,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(bool isUsedParts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Основная информация',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Название
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название товара *',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Укажите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Категория
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Категория',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Артикул (для новых запчастей) с поддержкой сканера
            if (!isUsedParts)
              Stack(
                children: [
                  TextFormField(
                    controller: _skuController,
                    focusNode: _skuFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Артикул (SKU)',
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: _isSearchingByBarcode
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      hintText: 'Отсканируйте штрих-код или введите вручную',
                    ),
                    onChanged: (value) {
                      // Обработка ввода для сканера
                      _barcodeScanner.handleInput(value);
                    },
                    onTap: () {
                      // При клике на поле - очищаем буфер сканера
                      _barcodeScanner.clearBuffer();
                    },
                  ),
                ],
              ),
            if (!isUsedParts) const SizedBox(height: 16),

            // Состояние
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Состояние',
                prefixIcon: Icon(Icons.check_circle),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('Новое')),
                DropdownMenuItem(value: 'used', child: Text('Б/У')),
                DropdownMenuItem(value: 'refurbished', child: Text('Восстановленное')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCondition = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Информация об авто',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Марка
            TextFormField(
              controller: _carBrandController,
              decoration: const InputDecoration(
                labelText: 'Марка авто',
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Модель
            TextFormField(
              controller: _carModelController,
              decoration: const InputDecoration(
                labelText: 'Модель авто',
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // VIN
            TextFormField(
              controller: _vinController,
              decoration: const InputDecoration(
                labelText: 'VIN / Номер кузова',
                prefixIcon: Icon(Icons.confirmation_number),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndQuantity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Цена и количество',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Количество *',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Укажите количество';
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'Количество должно быть больше 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Цена закупа *',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Укажите цену';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Цена должна быть больше 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCell() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Хранение',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _warehouseCellController,
              decoration: const InputDecoration(
                labelText: 'Ячейка хранения *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
                hintText: 'Например: A-1-2',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Укажите ячейку хранения';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Печать наклейки для товара
  Future<void> _printLabel({
    required String itemName,
    required String? sku,
    required double price,
    String? warehouseCell,
    required int quantity,
  }) async {
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
                Text('Печать наклеек...'),
              ],
            ),
          ),
        );
      }

      final success = await _printer.printLabel(
        itemName: itemName,
        sku: sku,
        price: price,
        warehouseCell: warehouseCell,
        quantity: quantity,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор печати
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Напечатано наклеек: $quantity'),
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
}

