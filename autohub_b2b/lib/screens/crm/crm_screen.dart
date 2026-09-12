import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/repositories/customers_repository.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final dio = ApiClient().dio;
  final _searchController = TextEditingController();
  final CustomersRepository _customersRepo =
      ServiceLocator().customersRepository;
  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
  bool isLoading = true;
  String? error;
  bool isForbidden = false;
  String? forbiddenMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      isLoading = true;
      error = null;
      isForbidden = false;
    });

    try {
      final loadedCustomers = await _customersRepo.getCustomers();

      setState(() {
        customers = loadedCustomers;
        filteredCustomers = customers;
        isLoading = false;
      });
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        setState(() {
          isForbidden = true;
          forbiddenMessage =
              (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к разделу «CRM». Войдите под владельцем или менеджером.';
          isLoading = false;
        });
      } else {
        setState(() {
          error = userFacingApiMessage(e);
          isLoading = false;
        });
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCustomers = customers;
      } else {
        filteredCustomers = customers.where((customer) {
          return customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.phone.toLowerCase().contains(query.toLowerCase()) ||
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
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок и поиск
          Container(
            padding: EdgeInsets.fromLTRB(
              isNarrow ? 16 : 24,
              isNarrow ? 16 : 24,
              isNarrow ? 16 : 24,
              isNarrow ? 12 : 24,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNarrow) ...[
                  Text(
                    'CRM',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Управление клиентами',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showCustomerDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Добавить клиента'),
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CRM',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Управление клиентами',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _showCustomerDialog(context),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Добавить клиента'),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: isNarrow ? 16 : 24),
                if (isNarrow) ...[
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск: имя, телефон, email…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                    ),
                    onChanged: _filterCustomers,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        // Фильтры будут реализованы позже
                      },
                      icon: const Icon(Icons.filter_list, size: 20),
                      label: const Text('Фильтры'),
                    ),
                  ),
                ] else ...[
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
                          // Фильтры будут реализованы позже
                        },
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Фильтры'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Список клиентов
          Expanded(child: _buildCustomersList()),
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    if (isForbidden) {
      return UnauthorizedPlaceholder(
        message: forbiddenMessage,
        isForbidden: false,
      );
    }

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
            Text(error!, textAlign: TextAlign.center),
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
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
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

    final wide = MediaQuery.sizeOf(context).width >= 768;
    return wide ? _buildCustomersTable() : _buildCustomersCardList();
  }

  Widget _buildCustomersCardList() {
    final dateFormat = DateFormat('dd.MM.yyyy');

    Widget infoLine(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filteredCustomers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final customer = filteredCustomers[index];
        final initial = customer.name.isNotEmpty
            ? customer.name.trim()[0].toUpperCase()
            : '?';

        return Material(
          color: AppTheme.surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showCustomerDialog(context, customer: customer),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        if (customer.phone.trim().isNotEmpty)
                          infoLine(Icons.phone_outlined, customer.phone),
                        if (customer.email != null &&
                            customer.email!.trim().isNotEmpty)
                          infoLine(Icons.email_outlined, customer.email!),
                        if (customer.carModel != null &&
                            customer.carModel!.trim().isNotEmpty)
                          infoLine(
                            Icons.directions_car_outlined,
                            customer.carModel!,
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'С ${dateFormat.format(customer.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showCustomerDialog(context, customer: customer),
                        tooltip: 'Редактировать',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _showDeleteDialog(context, customer),
                        tooltip: 'Удалить',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomersTable() {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      margin: const EdgeInsets.all(16),
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
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
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
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                customer.name.isNotEmpty
                                    ? customer.name.trim()[0].toUpperCase()
                                    : '?',
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
                        child: Text(
                          customer.phone.trim().isEmpty ? '-' : customer.phone,
                        ),
                      ),
                      Expanded(flex: 2, child: Text(customer.email ?? '-')),
                      Expanded(flex: 2, child: Text(customer.carModel ?? '-')),
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

  Future<void> _showCustomerDialog(
    BuildContext context, {
    CustomerModel? customer,
  }) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final formWidget = _CustomerFormDialog(
      customer: customer,
      dio: dio,
      onSuccess: () {
        Navigator.pop(context);
        _loadCustomers();
      },
    );
    if (isMobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => formWidget));
    } else {
      showDialog(context: context, builder: (_) => formWidget);
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    CustomerModel customer,
  ) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    DialogHelper.showConfirm(
      context: context,
      title: 'Удалить клиента?',
      message: 'Вы уверены что хотите удалить "${customer.name}"?',
      confirmText: 'Удалить',
      isDestructive: true,
      onConfirm: (ctx) async {
        await dio.delete('/api/customers/${customer.id}');
        if (context.mounted) {
          Navigator.pop(ctx);
          _loadCustomers();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Клиент удален')));
        }
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;
  final Dio dio;
  final VoidCallback onSuccess;

  const _CustomerFormDialog({
    this.customer,
    required this.dio,
    required this.onSuccess,
  });

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _carModelController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _carModelController = TextEditingController(text: c?.carModel ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _carModelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите имя клиента')));
      return;
    }
    final data = {
      'name': _nameController.text,
      'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
      'email': _emailController.text.isEmpty ? null : _emailController.text,
      'carModel': _carModelController.text.isEmpty
          ? null
          : _carModelController.text,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    };
    try {
      if (widget.customer != null) {
        await widget.dio.put(
          '/api/customers/${widget.customer!.id}',
          data: data,
        );
      } else {
        await widget.dio.post('/api/customers', data: data);
      }
      if (mounted) {
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.customer != null ? 'Клиент обновлен' : 'Клиент добавлен',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))));
      }
    }
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Имя *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Телефон',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _carModelController,
          decoration: const InputDecoration(
            labelText: 'Модель автомобиля',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.directions_car),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Примечания',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Редактировать клиента' : 'Добавить клиента'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildFormContent(),
        ),
      );
    }
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать клиента' : 'Добавить клиента'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(child: _buildFormContent()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}
