import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/incoming_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.docType == IncomingDocType.newParts) {
      _loadItems();
    }
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
      }
    });
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

            // Артикул (для новых запчастей)
            if (!isUsedParts)
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'Артикул (SKU)',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
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
}

