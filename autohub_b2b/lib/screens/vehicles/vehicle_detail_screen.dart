import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final dio = ApiClient().dio;
  VehicleModel? vehicle;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicleDetails();
  }

  Future<void> _loadVehicleDetails() async {
    setState(() => isLoading = true);

    try {
      final response = await dio.get('/api/vehicles/${widget.vehicleId}');
      setState(() {
        vehicle = VehicleModel.fromJson(response.data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateMileage() async {
    final mileageController = TextEditingController(
      text: vehicle?.currentMileage.toString() ?? '0',
    );

    final newMileage = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обновить пробег'),
        content: TextField(
          controller: mileageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Новый пробег (км)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(mileageController.text);
              Navigator.pop(context, value);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (newMileage != null) {
      try {
        await dio.put(
          '/api/vehicles/${widget.vehicleId}/mileage',
          data: {'mileage': newMileage},
        );
        _loadVehicleDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пробег обновлен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _recordService() async {
    final mileageController = TextEditingController(
      text: vehicle?.currentMileage.toString() ?? '0',
    );
    final nextMileageController = TextEditingController();
    DateTime? nextServiceDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Записать ТО'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Пробег при ТО (км) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nextMileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Следующее ТО при пробеге (км)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        nextServiceDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Следующее ТО по дате',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      nextServiceDate != null
                          ? DateFormat('dd.MM.yyyy').format(nextServiceDate!)
                          : 'Выбрать дату',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final mileage = int.tryParse(mileageController.text);
                if (mileage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Укажите пробег'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'mileage': mileage,
                  'serviceDate': DateTime.now().toIso8601String(),
                  'nextServiceMileage': int.tryParse(nextMileageController.text),
                  'nextServiceDate': nextServiceDate?.toIso8601String(),
                });
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await dio.post(
          '/api/vehicles/${widget.vehicleId}/service',
          data: result,
        );
        _loadVehicleDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ТО записано'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
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
        ],
      ),
      body: isLoading
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

                      // Технические характеристики
                      _buildTechSpecsCard(),
                      const SizedBox(height: 24),

                      // Обслуживание
                      _buildServiceCard(),
                      const SizedBox(height: 24),

                      // История заказов
                      _buildOrdersHistory(),
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
                const Icon(Icons.directions_car, size: 32, color: AppTheme.primaryColor),
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
                  Expanded(
                    child: _buildInfoItem('VIN', vehicle!.vin!),
                  ),
                if (vehicle!.color != null)
                  Expanded(
                    child: _buildInfoItem('Цвет', vehicle!.color!),
                  ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                    child: _buildInfoItem('Объем двигателя', '${vehicle!.engineVolume} л'),
                  ),
                if (vehicle!.enginePower != null)
                  Expanded(
                    child: _buildInfoItem('Мощность', '${vehicle!.enginePower} л.с.'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Обслуживание',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
            const SizedBox(height: 16),

            // Текущий пробег
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 32, color: AppTheme.primaryColor),
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
                        '${NumberFormat('#,###').format(vehicle!.currentMileage)} км',
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
                            DateFormat('dd.MM.yyyy').format(vehicle!.lastServiceDate!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (vehicle!.lastServiceMileage != null)
                            Text(
                              '${NumberFormat('#,###').format(vehicle!.lastServiceMileage)} км',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (vehicle!.lastServiceDate != null && vehicle!.nextServiceDate != null)
                  const SizedBox(width: 16),
                if (vehicle!.nextServiceDate != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vehicle!.needsService
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        border: Border.all(
                          color: vehicle!.needsService
                              ? Colors.orange.shade300
                              : Colors.green.shade300,
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
                                  color: Colors.orange.shade700,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('dd.MM.yyyy').format(vehicle!.nextServiceDate!),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: vehicle!.needsService
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                          if (vehicle!.daysUntilService != null)
                            Text(
                              vehicle!.needsService
                                  ? 'Просрочено на ${-vehicle!.daysUntilService!} дней'
                                  : 'Через ${vehicle!.daysUntilService} дней',
                              style: TextStyle(
                                fontSize: 12,
                                color: vehicle!.needsService
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          if (vehicle!.nextServiceMileage != null)
                            Text(
                              '${NumberFormat('#,###').format(vehicle!.nextServiceMileage)} км',
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Примечания',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vehicle!.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
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

  Widget _buildOrdersHistory() {
    final orders = vehicle!.orders ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'История заказов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                      backgroundColor: _getStatusColor(order['status']).withOpacity(0.2),
                      child: Icon(
                        Icons.receipt,
                        color: _getStatusColor(order['status']),
                      ),
                    ),
                    title: Text(order['orderNumber'] ?? 'Заказ #${order['id']}'),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy').format(
                        DateTime.parse(order['createdAt']),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${order['totalAmount']} ₸',
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
                            color: _getStatusColor(order['status']).withOpacity(0.2),
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
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
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

