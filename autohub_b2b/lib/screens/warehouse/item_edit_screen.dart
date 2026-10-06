import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/models/warehouse_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/image_upload_service.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';
import 'package:autohub_b2b/services/warehouse_service.dart';
import 'package:autohub_b2b/widgets/donor_origin_tile.dart';
import 'package:autohub_b2b/widgets/image_upload_widget.dart';
import 'package:autohub_b2b/widgets/item_catalog_editors.dart';
import 'package:flutter/services.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/offline_queue.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';

class ItemEditScreen extends StatefulWidget {
  final ItemModel item;

  const ItemEditScreen({super.key, required this.item});

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _oemController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _internalCodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchaseCostController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _warehouseCellController = TextEditingController();

  late final ApiClient _apiClient;
  late final ImageUploadService _imageUploadService;
  final WarehouseService _warehouseService = WarehouseService();

  String? _selectedCategory;
  String _selectedCondition = 'new';
  String? _selectedWarehouseId;
  bool _isLoading = false;
  bool _archived = false;
  List<String> _currentImages = [];
  List<Warehouse> _warehouses = [];
  List<ItemCrossReference> _crossReferences = [];
  List<ItemCompatibility> _compatibility = [];

  final List<String> _conditions = ['new', 'used', 'refurbished'];

  // Категории товаров (как в B2C, но без "Все")
  final List<String> _categories = [
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

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _imageUploadService = ImageUploadService(_apiClient);

    _hydrate(widget.item);
    _loadWarehouses();
    _loadFullItem();
  }

  void _hydrate(ItemModel item) {
    _nameController.text = item.name;
    final itemCategory = item.category;
    _selectedCategory =
        itemCategory != null && _categories.contains(itemCategory)
        ? itemCategory
        : null;
    _skuController.text = item.sku ?? '';
    _oemController.text = item.oem ?? '';
    _barcodeController.text = item.barcode ?? '';
    _brandController.text = item.brand ?? '';
    _internalCodeController.text = item.internalCode ?? '';
    _priceController.text = item.price.toString();
    _purchaseCostController.text = item.purchaseCost?.toString() ?? '';
    _quantityController.text = item.quantity.toString();
    _descriptionController.text = item.description ?? '';
    _warehouseCellController.text = item.warehouseCell ?? '';
    _selectedCondition = item.condition;
    _selectedWarehouseId = item.warehouseId;
    _currentImages = item.images ?? [];
    _archived = item.isArchived;
    _crossReferences = List.of(item.crossReferences ?? const []);
    _compatibility = List.of(item.compatibility ?? const []);
  }

  Future<void> _loadFullItem() async {
    final id = widget.item.id;
    if (id == null) return;
    try {
      final full = await ServiceLocator().itemsRepository.getItem(id);
      if (full != null && mounted) {
        setState(() => _hydrate(full));
      }
    } catch (_) {
      // Список уже показал карточку; аналоги подгрузятся при следующем открытии.
    }
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await _warehouseService.getWarehouses();
      setState(() {
        _warehouses = warehouses;
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _oemController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _internalCodeController.dispose();
    _priceController.dispose();
    _purchaseCostController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _warehouseCellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Редактировать товар',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.item.id != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveItem,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Быстрые действия'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _showPrintLabelDialog(context),
                            icon: const Icon(Icons.print),
                            label: const Text('Печать этикетки'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _copySkuToClipboard,
                            icon: const Icon(Icons.content_copy),
                            label: const Text('Скопировать SKU'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DonorOriginTile(item: widget.item),
                    // Основная информация
                    _buildSectionTitle('Основная информация'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название товара *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите название товара';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Категория',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            hint: const Text('Выберите категорию'),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            decoration: const InputDecoration(
                              labelText: 'Артикул (SKU)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _oemController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'OEM',
                              hintText: '04465-33450',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: const InputDecoration(
                              labelText: 'Штрихкод',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _brandController,
                            decoration: const InputDecoration(
                              labelText: 'Производитель',
                              hintText: 'Toyota, Bosch…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _internalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Внутренний код',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Цена и количество
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Цена (₸) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите цену';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Введите корректную цену';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Количество *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите количество';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Введите корректное количество';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    if (canSeeFinance(context)) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _purchaseCostController,
                        decoration: const InputDecoration(
                          labelText: 'Закупочная цена (₸)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount < 0) {
                            return 'Введите сумму';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Состояние товара
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'Состояние товара',
                        border: OutlineInputBorder(),
                      ),
                      items: _conditions.map((condition) {
                        String displayText;
                        switch (condition) {
                          case 'new':
                            displayText = 'Новый';
                            break;
                          case 'used':
                            displayText = 'Б/У';
                            break;
                          case 'refurbished':
                            displayText = 'Восстановленный';
                            break;
                          default:
                            displayText = condition;
                        }
                        return DropdownMenuItem(
                          value: condition,
                          child: Text(displayText),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCondition = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Описание
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Выбор склада
                    DropdownButtonFormField<String>(
                      value: _selectedWarehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Склад',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warehouse),
                      ),
                      hint: const Text('Выберите склад'),
                      isExpanded: true,
                      items: _warehouses.map((warehouse) {
                        return DropdownMenuItem(
                          value: warehouse.id,
                          child: Text(
                            warehouse.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWarehouseId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ячейка склада
                    TextFormField(
                      controller: _warehouseCellController,
                      decoration: const InputDecoration(
                        labelText: 'Ячейка склада',
                        hintText: 'Например: A-1-2',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Снят с продажи'),
                      subtitle: const Text(
                        'Не показывается покупателям, на складе остаётся',
                      ),
                      value: _archived,
                      onChanged: (value) => setState(() => _archived = value),
                    ),
                    const SizedBox(height: 16),
                    CrossReferencesEditor(
                      value: _crossReferences,
                      onChanged: (value) =>
                          setState(() => _crossReferences = value),
                    ),
                    const SizedBox(height: 16),
                    CompatibilityEditor(
                      value: _compatibility,
                      onChanged: (value) =>
                          setState(() => _compatibility = value),
                    ),
                    const SizedBox(height: 24),

                    // Изображения
                    if (widget.item.id != null) ...[
                      ImageUploadWidget(
                        item: widget.item.copyWith(images: _currentImages),
                        imageUploadService: _imageUploadService,
                        onImagesUpdated: (images) {
                          setState(() {
                            _currentImages = images;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Кнопки
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _copySkuToClipboard() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SKU не заполнен'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: sku));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SKU скопирован'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showPrintLabelDialog(BuildContext context) async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Печать этикетки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : (widget.item.name ?? 'Товар'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Количество этикеток',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(controller.text.trim()) ?? 1;
                Navigator.pop(dialogContext, qty < 1 ? 1 : qty);
              },
              child: const Text('Печать'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final price =
        double.tryParse(_priceController.text.trim()) ??
        (widget.item.price ?? 0);

    final printer = ThermalPrinterService();
    final success = await printer.printLabel(
      itemName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (widget.item.name ?? 'Товар'),
      sku: _skuController.text.trim().isNotEmpty
          ? _skuController.text.trim()
          : widget.item.sku,
      price: price,
      warehouseCell: _warehouseCellController.text.trim().isNotEmpty
          ? _warehouseCellController.text.trim()
          : widget.item.warehouseCell,
      quantity: result,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Этикетка отправлена на печать'
              : 'Не удалось напечатать этикетку',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final itemData = {
        'name': _nameController.text,
        'category': _selectedCategory,
        'sku': _skuController.text.isEmpty ? null : _skuController.text,
        'oem': _oemController.text.trim().isEmpty
            ? null
            : _oemController.text.trim(),
        'barcode': _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        'brand': _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        'internalCode': _internalCodeController.text.trim().isEmpty
            ? null
            : _internalCodeController.text.trim(),
        'price': double.parse(_priceController.text),
        if (canSeeFinance(context))
          'purchaseCost': _purchaseCostController.text.trim().isEmpty
              ? null
              : double.parse(_purchaseCostController.text.trim()),
        'quantity': int.parse(_quantityController.text),
        'condition': _selectedCondition,
        'status': _archived ? 'archived' : 'active',
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'warehouseCell': _warehouseCellController.text.isEmpty
            ? null
            : _warehouseCellController.text.trim(),
        'warehouseId': _selectedWarehouseId,
        'images': _currentImages,
        'crossReferences': _crossReferences.map((r) => r.toJson()).toList(),
        'compatibility': _compatibility.map((c) => c.toJson()).toList(),
      };

      final isCreate = widget.item.id == null;
      final localId = widget.item.id ?? OfflineQueue.newLocalIntId();
      final now = DateTime.now().toIso8601String();
      final snapshot = <String, dynamic>{
        ...itemData,
        'id': localId,
        'createdAt': widget.item.createdAt.toIso8601String(),
        'updatedAt': now,
      };
      final result = await OfflineQueue().send(
        method: isCreate ? 'POST' : 'PUT',
        path: isCreate ? '/api/items' : '/api/items/${widget.item.id}',
        body: itemData,
        entity: 'item',
        snapshot: snapshot,
        localId: '$localId',
      );
      final saved = ItemModel.fromJson(
        Map<String, dynamic>.from(
          result.queued ? snapshot : result.data as Map,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.queued
                  ? offlineSavedMessage
                  : isCreate
                  ? 'Товар успешно создан'
                  : 'Товар успешно обновлен',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Ошибка сохранения')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
