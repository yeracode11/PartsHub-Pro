import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await dio.get('/api/customers');
      final List<dynamic> data = response.data;

      setState(() {
        customers = data.map((json) => CustomerModel.fromJson(json)).toList();
        filteredCustomers = customers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCustomers = customers;
      } else {
        filteredCustomers = customers.where((customer) {
          return customer.name.toLowerCase().contains(query.toLowerCase()) ||
              (customer.phone?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (customer.email?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (customer.carModel?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок и поиск
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRM',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Управление клиентами',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showCustomerDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Добавить клиента'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск по имени, телефону, email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                        ),
                        onChanged: _filterCustomers,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Показать фильтры
                      },
                      icon: const Icon(Icons.filter_list),
                      label: const Text('Фильтры'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Список клиентов
          Expanded(
            child: _buildCustomersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCustomers,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              customers.isEmpty ? 'Нет клиентов' : 'Ничего не найдено',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              customers.isEmpty
                  ? 'Добавьте первого клиента'
                  : 'Попробуйте изменить запрос',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            if (customers.isEmpty) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCustomerDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Добавить клиента'),
              ),
            ],
          ],
        ),
      );
    }

    return _buildCustomersTable();
  }

  Widget _buildCustomersTable() {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Заголовок таблицы
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Имя',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Телефон',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Автомобиль',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Дата регистрации',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(width: 100), // Для кнопок действий
              ],
            ),
          ),

          // Строки таблицы
          Expanded(
            child: ListView.builder(
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = filteredCustomers[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < filteredCustomers.length - 1
                          ? const BorderSide(color: AppTheme.borderColor)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(
                                customer.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(customer.phone ?? '-'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(customer.email ?? '-'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(customer.carModel ?? '-'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(dateFormat.format(customer.createdAt)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showCustomerDialog(
                                context,
                                customer: customer,
                              ),
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _showDeleteDialog(context, customer),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
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

  void _showCustomerDialog(BuildContext context, {CustomerModel? customer}) {
    final isEdit = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final carModelController =
        TextEditingController(text: customer?.carModel ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Редактировать клиента' : 'Добавить клиента'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: carModelController,
                  decoration: const InputDecoration(
                    labelText: 'Модель автомобиля',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Примечания',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Укажите имя клиента')),
                );
                return;
              }

              final data = {
                'name': nameController.text,
                'phone': phoneController.text.isEmpty
                    ? null
                    : phoneController.text,
                'email': emailController.text.isEmpty
                    ? null
                    : emailController.text,
                'carModel': carModelController.text.isEmpty
                    ? null
                    : carModelController.text,
                'notes':
                    notesController.text.isEmpty ? null : notesController.text,
              };

              try {
                if (isEdit) {
                  await dio.put('/api/customers/${customer.id}', data: data);
                } else {
                  await dio.post('/api/customers', data: data);
                }

                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  _loadCustomers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Клиент обновлен'
                          : 'Клиент добавлен'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Добавить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('Вы уверены что хотите удалить "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await dio.delete('/api/customers/${customer.id}');
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  _loadCustomers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Клиент удален')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

