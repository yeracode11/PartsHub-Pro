import 'package:flutter/material.dart';
import '../models/warehouse_model.dart';

class ItemsFilterWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;
  final List<Warehouse> warehouses;
  
  const ItemsFilterWidget({
    Key? key,
    required this.onApplyFilters,
    required this.warehouses,
  }) : super(key: key);

  @override
  State<ItemsFilterWidget> createState() => _ItemsFilterWidgetState();
}

class _ItemsFilterWidgetState extends State<ItemsFilterWidget> {
  String? selectedCategory;
  String? selectedCondition;
  String? selectedWarehouseId;
  bool? inStock;
  double minPrice = 0;
  double maxPrice = 1000000;
  
  final List<String> categories = [
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

  final List<Map<String, String>> conditions = [
    {'value': 'new', 'label': 'Новый'},
    {'value': 'used', 'label': 'Б/У'},
    {'value': 'refurbished', 'label': 'Восстановленный'},
  ];

  void _applyFilters() {
    final filters = <String, dynamic>{};
    
    if (selectedCategory != null) filters['category'] = selectedCategory;
    if (selectedCondition != null) filters['condition'] = selectedCondition;
    if (selectedWarehouseId != null) filters['warehouseId'] = selectedWarehouseId;
    if (inStock != null) filters['inStock'] = inStock;
    if (minPrice > 0) filters['minPrice'] = minPrice;
    if (maxPrice < 1000000) filters['maxPrice'] = maxPrice;
    
    widget.onApplyFilters(filters);
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      selectedCategory = null;
      selectedCondition = null;
      selectedWarehouseId = null;
      inStock = null;
      minPrice = 0;
      maxPrice = 1000000;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Фильтры',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Категория
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все категории')),
                        ...categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (value) => setState(() => selectedCategory = value),
                    ),
                    const SizedBox(height: 16),

                    // Состояние
                    DropdownButtonFormField<String>(
                      value: selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'Состояние',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все состояния')),
                        ...conditions.map((c) => DropdownMenuItem(
                          value: c['value'],
                          child: Text(c['label']!),
                        )),
                      ],
                      onChanged: (value) => setState(() => selectedCondition = value),
                    ),
                    const SizedBox(height: 16),

                    // Склад
                    if (widget.warehouses.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedWarehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Склад',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Все склады')),
                          ...widget.warehouses.map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (value) => setState(() => selectedWarehouseId = value),
                      ),
                    const SizedBox(height: 16),

                    // Наличие
                    DropdownButtonFormField<bool?>(
                      value: inStock,
                      decoration: const InputDecoration(
                        labelText: 'Наличие',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Все товары')),
                        DropdownMenuItem(value: true, child: Text('В наличии')),
                        DropdownMenuItem(value: false, child: Text('Нет в наличии')),
                      ],
                      onChanged: (value) => setState(() => inStock = value),
                    ),
                    const SizedBox(height: 24),

                    // Диапазон цен
                    const Text(
                      'Диапазон цен',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: minPrice == 0 ? '' : minPrice.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              labelText: 'От',
                              border: OutlineInputBorder(),
                              suffixText: '₸',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                minPrice = double.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: maxPrice == 1000000 ? '' : maxPrice.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              labelText: 'До',
                              border: OutlineInputBorder(),
                              suffixText: '₸',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                maxPrice = double.tryParse(value) ?? 1000000;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      child: const Text('Применить'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

