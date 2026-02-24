import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/models/warehouse_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/image_upload_service.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';
import 'package:autohub_b2b/services/warehouse_service.dart';
import 'package:autohub_b2b/widgets/image_upload_widget.dart';
import 'package:flutter/services.dart';

class ItemEditScreen extends StatefulWidget {
  final ItemModel item;

  const ItemEditScreen({
    super.key,
    required this.item,
  });

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
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
  List<String> _currentImages = [];
  List<Warehouse> _warehouses = [];

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
    
    // Инициализируем поля формы
    _nameController.text = widget.item.name ?? '';
    // Проверяем, что категория существует в списке, иначе устанавливаем null
    final itemCategory = widget.item.category;
    _selectedCategory = itemCategory != null && _categories.contains(itemCategory) 
        ? itemCategory 
        : null;
    _skuController.text = widget.item.sku ?? '';
    _priceController.text = widget.item.price.toString();
    _quantityController.text = widget.item.quantity.toString();
    _descriptionController.text = widget.item.description ?? '';
    _warehouseCellController.text = widget.item.warehouseCell ?? '';
    _selectedCondition = widget.item.condition ?? 'new';
    _selectedWarehouseId = widget.item.warehouseId;
    _currentImages = widget.item.images ?? [];
    
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await _warehouseService.getWarehouses();
      setState(() {
        _warehouses = warehouses;
      });
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
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
                            onPressed: _isLoading ? null : () => _showPrintLabelDialog(context),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

    final price = double.tryParse(_priceController.text.trim()) ??
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
          success ? 'Этикетка отправлена на печать' : 'Не удалось напечатать этикетку',
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
        'price': double.parse(_priceController.text),
        'quantity': int.parse(_quantityController.text),
        'condition': _selectedCondition,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'warehouseCell': _warehouseCellController.text.isEmpty ? null : _warehouseCellController.text.trim(),
        'warehouseId': _selectedWarehouseId,
        'images': _currentImages,
      };

      if (widget.item.id == null) {
        // Создание нового товара
        final response = await _apiClient.dio.post('/api/items', data: itemData);
        final newItem = ItemModel.fromJson(response.data);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Товар успешно создан'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).pop(newItem);
        }
      } else {
        // Обновление существующего товара
        final response = await _apiClient.dio.put(
          '/api/items/${widget.item.id}',
          data: itemData,
        );
        final updatedItem = ItemModel.fromJson(response.data);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Товар успешно обновлен'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).pop(updatedItem);
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
      setState(() {
        _isLoading = false;
      });
    }
  }
}
