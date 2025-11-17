import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:dio/dio.dart';

class ServiceRemindersWidget extends StatefulWidget {
  const ServiceRemindersWidget({super.key});

  @override
  State<ServiceRemindersWidget> createState() => _ServiceRemindersWidgetState();
}

class _ServiceRemindersWidgetState extends State<ServiceRemindersWidget> {
  final dio = ApiClient().dio;
  List<VehicleModel> upcomingService = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingService();
  }

  Future<void> _loadUpcomingService() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);

    try {
      final response = await dio.get('/api/vehicles/upcoming-service');
      final List<dynamic> data = response.data;

      if (!mounted) return;
      
      setState(() {
        upcomingService = data.map((json) => VehicleModel.fromJson(json)).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() => isLoading = false);
      print('Error loading upcoming service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (upcomingService.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              Text(
                'Все автомобили обслужены!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Нет автомобилей, требующих ТО',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Напоминания о ТО',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${upcomingService.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...upcomingService.map((vehicle) => _buildReminderItem(vehicle)),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(VehicleModel vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vehicle.needsService
            ? Colors.red.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vehicle.needsService
              ? Colors.red.shade300
              : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: vehicle.needsService
                ? Colors.red.shade700
                : Colors.orange.shade700,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: vehicle.needsService
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.plateNumber,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Владелец: ${vehicle.customerName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (vehicle.daysUntilService != null)
                Text(
                  vehicle.needsService
                      ? 'Просрочено!'
                      : 'Через ${vehicle.daysUntilService} дней',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: vehicle.needsService
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              if (vehicle.kmUntilService != null)
                Text(
                  '${vehicle.kmUntilService} км до ТО',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

