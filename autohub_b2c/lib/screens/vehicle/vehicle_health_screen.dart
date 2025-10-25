import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/vehicle_model.dart';
import '../../services/vehicles_api_service.dart';
import '../../services/api_client.dart';

class VehicleHealthScreen extends StatefulWidget {
  const VehicleHealthScreen({super.key});

  @override
  State<VehicleHealthScreen> createState() => _VehicleHealthScreenState();
}

class _VehicleHealthScreenState extends State<VehicleHealthScreen> {
  late final VehiclesApiService _apiService;
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = VehiclesApiService(ApiClient());
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final vehicles = await _apiService.getUserVehicles();
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Здоровье автомобиля'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              GoRouter.of(context).go('/add-vehicle');
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
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
              onPressed: _loadVehicles,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет автомобилей',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте свой первый автомобиль',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/add-vehicle');
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить автомобиль'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return _buildVehicleCard(vehicle);
      },
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          _showVehicleDetails(vehicle);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с названием автомобиля
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.fullName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          vehicle.plateNumber,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Информация об автомобиле
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Пробег',
                      '${vehicle.currentMileage} км',
                      Icons.speed,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Топливо',
                      vehicle.fuelTypeDisplay,
                      Icons.local_gas_station,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'КПП',
                      vehicle.transmissionDisplay,
                      Icons.settings,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Статус обслуживания
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vehicle.serviceStatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: vehicle.serviceStatusColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      vehicle.needsService ? Icons.warning : Icons.check_circle,
                      color: vehicle.serviceStatusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Обслуживание',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            vehicle.serviceStatus,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: vehicle.serviceStatusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (vehicle.nextServiceMileage != null)
                            Text(
                              'До ТО: ${vehicle.mileageToService} км',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showVehicleDetails(Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Text(
                    vehicle.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Детальная информация
              _buildDetailSection('Основная информация', [
                _buildDetailRow('Марка', vehicle.brand),
                _buildDetailRow('Модель', vehicle.model),
                _buildDetailRow('Год', vehicle.year.toString()),
                _buildDetailRow('Цвет', vehicle.color ?? 'Не указан'),
                _buildDetailRow('Госномер', vehicle.plateNumber),
                if (vehicle.vin != null) _buildDetailRow('VIN', vehicle.vin!),
              ]),

              const SizedBox(height: 24),

              _buildDetailSection('Технические характеристики', [
                _buildDetailRow('Топливо', vehicle.fuelTypeDisplay),
                _buildDetailRow('КПП', vehicle.transmissionDisplay),
                if (vehicle.engineVolume != null)
                  _buildDetailRow('Объем двигателя', '${vehicle.engineVolume} л'),
                if (vehicle.enginePower != null)
                  _buildDetailRow('Мощность', '${vehicle.enginePower} л.с.'),
              ]),

              const SizedBox(height: 24),

              _buildDetailSection('Обслуживание', [
                _buildDetailRow('Текущий пробег', '${vehicle.currentMileage} км'),
                if (vehicle.lastServiceMileage != null)
                  _buildDetailRow('Последнее ТО', '${vehicle.lastServiceMileage} км'),
                if (vehicle.nextServiceMileage != null)
                  _buildDetailRow('Следующее ТО', '${vehicle.nextServiceMileage} км'),
                _buildDetailRow('Статус', vehicle.serviceStatus),
              ]),

              if (vehicle.notes != null && vehicle.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDetailSection('Заметки', [
                  Text(
                    vehicle.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
