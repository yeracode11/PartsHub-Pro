import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:dio/dio.dart';

class WarehouseLocationScreen extends StatefulWidget {
  const WarehouseLocationScreen({super.key});

  @override
  State<WarehouseLocationScreen> createState() => _WarehouseLocationScreenState();
}

class _WarehouseLocationScreenState extends State<WarehouseLocationScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Загружаем товары с ячейками склада
      final response = await dio.get('/api/items');
      final List<dynamic> data = response.data;

      if (!mounted) return;
      
      // Группируем товары по ячейкам склада
      final Map<String, Map<String, dynamic>> locationMap = {};
      
      for (var item in data) {
        final warehouseCell = item['warehouseCell'] as String?;
        if (warehouseCell != null && warehouseCell.isNotEmpty) {
          if (!locationMap.containsKey(warehouseCell)) {
            locationMap[warehouseCell] = {
              'cell': warehouseCell,
              'items': <Map<String, dynamic>>[],
              'totalQuantity': 0,
            };
          }
          locationMap[warehouseCell]!['items'].add(item);
          locationMap[warehouseCell]!['totalQuantity'] = 
              (locationMap[warehouseCell]!['totalQuantity'] as int) + 
              (item['quantity'] as int? ?? 0);
        }
      }

      setState(() {
        _locations = locationMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Расположение товаров'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка загрузки',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLocations,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет данных о расположении',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавьте товары с указанием ячеек склада',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Поиск
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Поиск по ячейке...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceColor,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        // Список ячеек
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _locations.length,
                            itemBuilder: (context, index) {
                              final location = _locations[index];
                              final cell = location['cell'] as String;
                              final items = location['items'] as List<dynamic>;
                              final totalQuantity = location['totalQuantity'] as int;

                              // Фильтрация по поиску
                              if (_searchController.text.isNotEmpty) {
                                if (!cell.toLowerCase().contains(
                                    _searchController.text.toLowerCase())) {
                                  return const SizedBox.shrink();
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    'Ячейка: $cell',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Товаров: ${items.length} | Всего: $totalQuantity шт.',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  children: [
                                    ...items.map((item) {
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 20,
                                        ),
                                        title: Text(
                                          item['name'] ?? 'Без названия',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        trailing: Text(
                                          '${item['quantity'] ?? 0} шт.',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

