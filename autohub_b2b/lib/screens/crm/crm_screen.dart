import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:autohub_b2b/screens/vehicles/vehicle_detail_screen.dart';
import 'package:autohub_b2b/screens/vehicles/vehicles_screen.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/repositories/customers_repository.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final q = query.toLowerCase().trim();
        filteredCustomers = customers.where((customer) {
          final matchesVehicle = customer.vehicles.any((v) =>
              v.brand.toLowerCase().contains(q) ||
              v.model.toLowerCase().contains(q) ||
              v.plateNumber.toLowerCase().contains(q) ||
              (v.vin?.toLowerCase().contains(q) ?? false));
          return customer.name.toLowerCase().contains(q) ||
              customer.phone.toLowerCase().contains(q) ||
              (customer.email?.toLowerCase().contains(q) ?? false) ||
              (customer.carModel?.toLowerCase().contains(q) ?? false) ||
              matchesVehicle;
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось совершить вызов')),
      );
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      digits = '7${digits.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть WhatsApp')),
      );
    }
  }

  Future<void> _addVehicleForCustomer(CustomerModel customer) async {
    if (customer.id == null) return;
    await showVehicleDialog(
      context,
      preselectedCustomerId: customer.id,
      onSave: _loadCustomers,
    );
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
        final hasPhone = customer.phone.trim().isNotEmpty;

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
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            if (hasPhone)
                              infoLine(Icons.phone_outlined, customer.phone),
                            if (customer.email != null &&
                                customer.email!.trim().isNotEmpty)
                              infoLine(Icons.email_outlined, customer.email!),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPhone) ...[
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, size: 20),
                              onPressed: () => _makePhoneCall(customer.phone),
                              tooltip: 'Позвонить',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                              ),
                              onPressed: () => _openWhatsApp(customer.phone),
                              tooltip: 'WhatsApp',
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showCustomerDialog(
                              context,
                              customer: customer,
                            ),
                            tooltip: 'Редактировать',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _showDeleteDialog(context, customer),
                            tooltip: 'Удалить',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Секция Автопарка / Гаража клиента
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Гараж (${customer.vehiclesCount}):',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _addVehicleForCustomer(customer),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Добавить авто',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (customer.hasVehicles)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: customer.vehicles.map((v) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VehicleDetailScreen(
                                          vehicleId: v.id,
                                        ),
                                      ),
                                    ).then((_) => _loadCustomers());
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: v.needsService
                                          ? Colors.orange.withValues(
                                              alpha: 0.12,
                                            )
                                          : AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: v.needsService
                                            ? Colors.orange
                                            : AppTheme.borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.directions_car,
                                          size: 14,
                                          color: v.needsService
                                              ? Colors.orange
                                              : AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${v.brand} ${v.model}${v.plateNumber.isNotEmpty ? ' • ${v.plateNumber}' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: v.needsService
                                                ? Colors.orange.shade900
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (v.needsService) ...[
                                          const SizedBox(width: 4),
                                          const Text(
                                            'ТО',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            Text(
                              customer.carModel != null &&
                                      customer.carModel!.isNotEmpty
                                  ? 'Указана модель: ${customer.carModel}'
                                  : 'Нет добавленных автомобилей',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'С ${dateFormat.format(customer.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
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
                  flex: 3,
                  child: Text(
                    'Гараж (Автомобили)',
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
                const SizedBox(width: 140), // Для кнопок действий
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
                      Expanded(
                        flex: 3,
                        child: customer.hasVehicles
                            ? Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...customer.vehicles.map((v) => InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  VehicleDetailScreen(
                                                    vehicleId: v.id,
                                                  ),
                                            ),
                                          ).then((_) => _loadCustomers());
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: v.needsService
                                                ? Colors.orange.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : AppTheme.backgroundColor,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: v.needsService
                                                  ? Colors.orange
                                                  : AppTheme.borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.directions_car,
                                                size: 13,
                                                color: v.needsService
                                                    ? Colors.orange
                                                    : AppTheme.primaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${v.brand} ${v.model}${v.plateNumber.isNotEmpty ? ' (${v.plateNumber})' : ''}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: v.needsService
                                                      ? Colors.orange.shade900
                                                      : AppTheme.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        _addVehicleForCustomer(customer),
                                    tooltip: 'Добавить авто в гараж',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (customer.carModel != null &&
                                              customer.carModel!.isNotEmpty)
                                          ? customer.carModel!
                                          : '—',
                                      style: TextStyle(
                                        color: (customer.carModel != null &&
                                                customer.carModel!.isNotEmpty)
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        _addVehicleForCustomer(customer),
                                    tooltip: 'Добавить авто в гараж',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(dateFormat.format(customer.createdAt)),
                      ),
                      SizedBox(
                        width: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (customer.phone.trim().isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.phone_outlined, size: 18),
                                onPressed: () =>
                                    _makePhoneCall(customer.phone),
                                tooltip: 'Позвонить',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _openWhatsApp(customer.phone),
                                tooltip: 'WhatsApp',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showCustomerDialog(
                                context,
                                customer: customer,
                              ),
                              tooltip: 'Редактировать',
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _showDeleteDialog(context, customer),
                              tooltip: 'Удалить',
                              visualDensity: VisualDensity.compact,
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
    await showCustomerDialog(
      context,
      customer: customer,
      onSuccess: _loadCustomers,
    );
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

Future<void> showCustomerDialog(
  BuildContext context, {
  CustomerModel? customer,
  VoidCallback? onSuccess,
}) async {
  if (!await ensureAuthenticated(context)) return;
  if (!context.mounted) return;
  final dio = ApiClient().dio;
  final isMobile = MediaQuery.of(context).size.width < 768;
  final formWidget = CustomerFormDialog(
    customer: customer,
    dio: dio,
    onSuccess: () {
      Navigator.pop(context);
      onSuccess?.call();
    },
  );
  if (isMobile) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => formWidget));
  } else {
    await showDialog(context: context, builder: (_) => formWidget);
  }
}

class CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;
  final Dio dio;
  final VoidCallback onSuccess;

  const CustomerFormDialog({
    super.key,
    this.customer,
    required this.dio,
    required this.onSuccess,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _carModelController;
  late final TextEditingController _notesController;

  List<VehicleModel> _vehicles = [];
  bool _isLoadingVehicles = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _carModelController = TextEditingController(text: c?.carModel ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');

    if (c != null) {
      _vehicles = List.from(c.vehicles);
      _loadFreshVehicles(c.id);
    }
  }

  Future<void> _loadFreshVehicles(int? customerId) async {
    if (customerId == null) return;
    setState(() => _isLoadingVehicles = true);
    try {
      final res = await widget.dio.get('/api/customers/$customerId');
      if (mounted && res.data != null) {
        final updated = CustomerModel.fromJson(res.data as Map<String, dynamic>);
        setState(() {
          _vehicles = updated.vehicles;
          _isLoadingVehicles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось совершить вызов')),
      );
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      digits = '7${digits.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть WhatsApp')),
      );
    }
  }

  Future<void> _addVehicle() async {
    if (widget.customer?.id == null) return;
    await showVehicleDialog(
      context,
      preselectedCustomerId: widget.customer!.id,
      onSave: () {
        _loadFreshVehicles(widget.customer!.id);
        widget.onSuccess();
      },
    );
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
    final c = widget.customer;
    final hasPhone = c?.phone != null && c!.phone.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPhone) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _makePhoneCall(c.phone),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Позвонить'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openWhatsApp(c.phone),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('WhatsApp'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
            labelText: 'Примечание по авто (строка)',
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

        // Секция Автопарка клиента в CRM
        if (widget.customer != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.garage_outlined,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Гараж клиента (${_vehicles.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addVehicle,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить авто'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingVehicles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'В гараже клиента пока нет добавленных автомобилей',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _vehicles.map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: v.needsService
                          ? Colors.orange
                          : AppTheme.borderColor,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.directions_car,
                      color: v.needsService
                          ? Colors.orange
                          : AppTheme.primaryColor,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (v.needsService)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Требуется ТО',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      'Пробег: ${v.currentMileage} км${v.vin != null && v.vin!.isNotEmpty ? ' • VIN: ${v.vin}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VehicleDetailScreen(vehicleId: v.id),
                        ),
                      ).then((_) {
                        if (widget.customer?.id != null) {
                          _loadFreshVehicles(widget.customer!.id);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
        ],
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
        width: 540,
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
