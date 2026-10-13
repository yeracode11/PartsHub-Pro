import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:autohub_b2b/models/vehicle_service_record_model.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/screens/crm/crm_screen.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/screens/vehicles/vehicles_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final dio = ApiClient().dio;
  VehicleModel? vehicle;
  List<VehicleServiceRecordModel>? serviceHistory;
  bool isLoading = true;
  bool isForbidden = false;
  String? forbiddenMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetails();
  }

  Future<void> _loadVehicleDetails() async {
    setState(() {
      isLoading = true;
      isForbidden = false;
    });

    try {
      final results = await Future.wait([
        dio.get('/api/vehicles/${widget.vehicleId}'),
        _loadServiceHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        vehicle = VehicleModel.fromJson((results[0] as Response).data);
        serviceHistory = results[1] as List<VehicleServiceRecordModel>?;
        isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        setState(() {
          isForbidden = true;
          forbiddenMessage =
              (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к просмотру этого автомобиля.';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Ошибка загрузки')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingApiMessage(e, prefix: 'Ошибка загрузки')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// null — бэкенд без сервисной истории (старая версия): раздел не показываем.
  Future<List<VehicleServiceRecordModel>?> _loadServiceHistory() async {
    try {
      final response = await dio.get(
        '/api/vehicles/${widget.vehicleId}/service-history',
      );
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(VehicleServiceRecordModel.fromJson)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  Future<void> _updateMileage() async {
    final current = vehicle?.currentMileage ?? 0;
    final newMileage = await showDialog<int>(
      context: context,
      builder: (context) => _MileageDialog(currentMileage: current),
    );
    if (newMileage == null) return;

    try {
      await dio.put(
        '/api/vehicles/${widget.vehicleId}/mileage',
        data: {'mileage': newMileage},
      );
      await _loadVehicleDetails();
      _showMessage('Пробег обновлен');
    } catch (e) {
      _showMessage(userFacingApiMessage(e, prefix: 'Ошибка'), error: true);
    }
  }

  Future<void> _recordService() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _ServiceDialog(currentMileage: vehicle?.currentMileage ?? 0),
    );
    if (result == null) return;

    try {
      await dio.post('/api/vehicles/${widget.vehicleId}/service', data: result);
      await _loadVehicleDetails();
      _showMessage('ТО записано');
    } catch (e) {
      _showMessage(userFacingApiMessage(e, prefix: 'Ошибка'), error: true);
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

  Future<void> _openCustomerInCrm() async {
    if (vehicle?.customerId == null || vehicle!.customerId == 0) return;
    try {
      final res = await dio.get('/api/customers/${vehicle!.customerId}');
      if (!mounted) return;
      final customer = CustomerModel.fromJson(res.data as Map<String, dynamic>);
      await showCustomerDialog(
        context,
        customer: customer,
        onSuccess: _loadVehicleDetails,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingApiMessage(e, prefix: 'Ошибка загрузки клиента'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editVehicle() async {
    if (vehicle == null) return;
    await showVehicleDialog(
      context,
      vehicle: vehicle,
      onSave: _loadVehicleDetails,
    );
  }

  Future<void> _deleteVehicle() async {
    if (vehicle == null) return;
    if (!await ensureAuthenticated(context)) return;
    if (!mounted) return;

    final confirm = await DialogHelper.showConfirmSimple(
      context: context,
      title: 'Удалить автомобиль?',
      message: 'Вы уверены, что хотите удалить ${vehicle!.displayName}?',
      confirmText: 'Удалить',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await dio.delete('/api/vehicles/${widget.vehicleId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Автомобиль удален'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingApiMessage(e, prefix: 'Ошибка удаления')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(vehicle?.displayName ?? 'Загрузка...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicleDetails,
            tooltip: 'Обновить',
          ),
          if (vehicle != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editVehicle,
              tooltip: 'Изменить',
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (value) {
                if (value == 'delete') _deleteVehicle();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Удалить',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: isForbidden
          ? UnauthorizedPlaceholder(
              message: forbiddenMessage,
              isForbidden: false,
            )
          : isLoading
          ? const Center(child: CircularProgressIndicator())
          : vehicle == null
          ? const Center(child: Text('Автомобиль не найден'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Основная информация
                  _buildMainInfoCard(),
                  const SizedBox(height: 24),

                  // Владелец (CRM)
                  _buildOwnerCard(),
                  const SizedBox(height: 24),

                  // Технические характеристики
                  _buildTechSpecsCard(),
                  const SizedBox(height: 24),

                  // Обслуживание
                  _buildServiceCard(),
                  if (serviceHistory != null) ...[
                    const SizedBox(height: 24),
                    _buildServiceHistory(),
                  ],
                  const SizedBox(height: 24),

                  // История заказов
                  _buildOrdersHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildOwnerCard() {
    final hasPhone =
        vehicle?.customerPhone != null &&
        vehicle!.customerPhone!.trim().isNotEmpty;
    final hasEmail =
        vehicle?.customerEmail != null &&
        vehicle!.customerEmail!.trim().isNotEmpty;
    final hasNotes =
        vehicle?.customerNotes != null &&
        vehicle!.customerNotes!.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 24,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                // Заголовок сжимается, а не выталкивает кнопку за край на узком экране.
                const Expanded(
                  child: Text(
                    'Владелец',
                    style: AppTheme.sectionTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openCustomerInCrm,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('В CRM'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    (vehicle?.customerName.isNotEmpty ?? false)
                        ? vehicle!.customerName.trim()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle?.customerName ?? 'Неизвестный клиент',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasPhone)
                        Text(
                          vehicle!.customerPhone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasEmail || hasNotes) ...[
              const SizedBox(height: 12),
              if (hasEmail)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        vehicle!.customerEmail!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasNotes)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicle!.customerNotes!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            if (hasPhone) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(vehicle!.customerPhone!),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Позвонить'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openWhatsApp(vehicle!.customerPhone!),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('WhatsApp'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle!.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Владелец: ${vehicle!.customerName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Госномер', vehicle!.plateNumber),
                ),
                if (vehicle!.vin != null)
                  Expanded(child: _buildInfoItem('VIN', vehicle!.vin!)),
                if (vehicle!.color != null)
                  Expanded(child: _buildInfoItem('Цвет', vehicle!.color!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechSpecsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Технические характеристики',
              style: AppTheme.sectionTitle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Топливо', vehicle!.fuelTypeDisplay),
                ),
                Expanded(
                  child: _buildInfoItem('КПП', vehicle!.transmissionDisplay),
                ),
                if (vehicle!.engineVolume != null)
                  Expanded(
                    child: _buildInfoItem(
                      'Объем двигателя',
                      '${vehicle!.engineVolume} л',
                    ),
                  ),
                if (vehicle!.enginePower != null)
                  Expanded(
                    child: _buildInfoItem(
                      'Мощность',
                      '${vehicle!.enginePower} л.с.',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              const Text('Обслуживание', style: AppTheme.sectionTitle),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _updateMileage,
                  icon: const Icon(Icons.speed, size: 18),
                  label: const Text('Обновить пробег'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _recordService,
                  icon: const Icon(Icons.build, size: 18),
                  label: const Text('Записать ТО'),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Text('Обслуживание', style: AppTheme.sectionTitle),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _updateMileage,
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Обновить пробег'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _recordService,
                    icon: const Icon(Icons.build, size: 18),
                    label: const Text('Записать ТО'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Текущий пробег
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed,
                    size: 32,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Текущий пробег',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,###', 'ru_RU').format(vehicle!.currentMileage)} км',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Информация о ТО
            Row(
              children: [
                if (vehicle!.lastServiceDate != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Последнее ТО',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'dd.MM.yyyy',
                            ).format(vehicle!.lastServiceDate!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (vehicle!.lastServiceMileage != null)
                            Text(
                              '${NumberFormat('#,###', 'ru_RU').format(vehicle!.lastServiceMileage)} км',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (vehicle!.lastServiceDate != null && _hasNextService)
                  const SizedBox(width: 16),
                if (_hasNextService)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vehicle!.needsService
                            ? AppTheme.warningSoft
                            : AppTheme.successSoft,
                        border: Border.all(
                          color: vehicle!.needsService
                              ? AppTheme.warningBorder
                              : AppTheme.successBorder,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Следующее ТО',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (vehicle!.needsService)
                                Icon(
                                  Icons.warning,
                                  size: 16,
                                  color: AppTheme.warningColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle!.nextServiceDate != null
                                ? DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(vehicle!.nextServiceDate!)
                                : '${NumberFormat('#,###', 'ru_RU').format(vehicle!.nextServiceMileage)} км',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: vehicle!.needsService
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                            ),
                          ),
                          if (vehicle!.kmUntilService != null &&
                              vehicle!.nextServiceDate == null)
                            Text(
                              vehicle!.kmUntilService! <= 0
                                  ? 'Пробег превышен на ${NumberFormat('#,###', 'ru_RU').format(-vehicle!.kmUntilService!)} км'
                                  : 'Осталось ${NumberFormat('#,###', 'ru_RU').format(vehicle!.kmUntilService)} км',
                              style: TextStyle(
                                fontSize: 12,
                                color: vehicle!.needsService
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                              ),
                            ),
                          if (vehicle!.daysUntilService != null)
                            Text(
                              vehicle!.daysUntilService! < 0
                                  ? 'Просрочено на ${-vehicle!.daysUntilService!} дн.'
                                  : 'Через ${vehicle!.daysUntilService} дн.',
                              style: TextStyle(
                                fontSize: 12,
                                color: vehicle!.needsService
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                              ),
                            ),
                          if (vehicle!.nextServiceMileage != null &&
                              vehicle!.nextServiceDate != null)
                            Text(
                              '${NumberFormat('#,###', 'ru_RU').format(vehicle!.nextServiceMileage)} км',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (vehicle!.notes != null && vehicle!.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Примечания',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vehicle!.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasNextService =>
      vehicle!.nextServiceDate != null || vehicle!.nextServiceMileage != null;

  Widget _buildServiceHistory() {
    final records = serviceHistory!;
    final km = NumberFormat('#,###', 'ru_RU');
    final date = DateFormat('dd.MM.yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('История обслуживания', style: AppTheme.sectionTitle),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Записей пока нет. Нажмите «Записать ТО».',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              for (var i = 0; i < records.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.format(records[i].serviceDate)} · ${km.format(records[i].mileage)} км',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (records[i].description != null) ...[
                            const SizedBox(height: 2),
                            Text(records[i].description!),
                          ],
                          if (records[i].nextServiceMileage != null ||
                              records[i].nextServiceDate != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Следующее: ${[if (records[i].nextServiceDate != null) date.format(records[i].nextServiceDate!), if (records[i].nextServiceMileage != null) '${km.format(records[i].nextServiceMileage)} км'].join(' или ')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersHistory() {
    final orders = vehicle!.orders ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('История заказов', style: AppTheme.sectionTitle),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Нет заказов для этого автомобиля',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(
                        order['status'],
                      ).withValues(alpha: 0.2),
                      child: Icon(
                        Icons.receipt,
                        color: _getStatusColor(order['status']),
                      ),
                    ),
                    title: Text(
                      order['orderNumber'] ?? 'Заказ #${order['id']}',
                    ),
                    subtitle: Text(
                      DateFormat(
                        'dd.MM.yyyy',
                      ).format(DateTime.parse(order['createdAt'])),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,###', 'ru_RU').format(num.tryParse('${order['totalAmount']}') ?? 0)} ₸',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              order['status'],
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(order['status']),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(order['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'processing':
        return AppTheme.primaryColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Завершен';
      case 'processing':
        return 'В работе';
      case 'cancelled':
        return 'Отменен';
      case 'pending':
        return 'Ожидает';
      default:
        return status;
    }
  }
}

class _MileageDialog extends StatefulWidget {
  const _MileageDialog({required this.currentMileage});

  final int currentMileage;

  @override
  State<_MileageDialog> createState() => _MileageDialogState();
}

class _MileageDialogState extends State<_MileageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: widget.currentMileage.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Обновить пробег'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Новый пробег (км)',
            helperText:
                'Сейчас ${NumberFormat('#,###', 'ru_RU').format(widget.currentMileage)} км',
          ),
          validator: (value) {
            final mileage = int.tryParse(value?.trim() ?? '');
            if (mileage == null || mileage < 0) return 'Укажите пробег';
            if (mileage < widget.currentMileage) {
              return 'Не меньше текущего пробега';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({required this.currentMileage});

  final int currentMileage;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _mileage = TextEditingController(
    text: widget.currentMileage.toString(),
  );
  final _description = TextEditingController();
  final _nextMileage = TextEditingController();
  DateTime _serviceDate = DateTime.now();
  DateTime? _nextServiceDate;
  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    _mileage.dispose();
    _description.dispose();
    _nextMileage.dispose();
    super.dispose();
  }

  Future<void> _pickServiceDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (date != null) setState(() => _serviceDate = date);
  }

  Future<void> _pickNextDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _nextServiceDate ?? _serviceDate.add(const Duration(days: 180)),
      firstDate: _serviceDate.add(const Duration(days: 1)),
      lastDate: _serviceDate.add(const Duration(days: 365 * 3)),
    );
    if (date != null) setState(() => _nextServiceDate = date);
  }

  String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final next = _nextMileage.text.trim();
    Navigator.pop(context, {
      'mileage': int.parse(_mileage.text.trim()),
      'serviceDate': _isoDate(_serviceDate),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'nextServiceMileage': next.isEmpty ? null : int.parse(next),
      'nextServiceDate': _nextServiceDate == null
          ? null
          : _isoDate(_nextServiceDate!),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Записать ТО'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DateField(
                  label: 'Дата ТО',
                  value: _dateFormat.format(_serviceDate),
                  onTap: _pickServiceDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mileage,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Пробег при ТО (км) *',
                  ),
                  validator: (value) {
                    final mileage = int.tryParse(value?.trim() ?? '');
                    return mileage == null || mileage < 0
                        ? 'Укажите пробег'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Что сделано',
                    hintText: 'Например: замена масла и фильтров',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextMileage,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Следующее ТО при пробеге (км)',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final next = int.tryParse(text);
                    final mileage = int.tryParse(_mileage.text.trim()) ?? 0;
                    if (next == null) return 'Укажите число';
                    if (next <= mileage) return 'Больше пробега при ТО';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Следующее ТО по дате',
                  value: _nextServiceDate == null
                      ? 'Не указано'
                      : _dateFormat.format(_nextServiceDate!),
                  onTap: _pickNextDate,
                  onClear: _nextServiceDate == null
                      ? null
                      : () => setState(() => _nextServiceDate = null),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today, size: 20)
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Очистить',
                  onPressed: onClear,
                ),
        ),
        child: Text(value),
      ),
    );
  }
}
