import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/screens/vehicles/vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final dio = ApiClient().dio;
  List<VehicleModel> vehicles = [];
  List<VehicleModel> filteredVehicles = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => isLoading = true);

    try {
      final response = await dio.get('/api/vehicles');
      final List<dynamic> data = response.data;

      setState(() {
        vehicles = data.map((json) => VehicleModel.fromJson(json)).toList();
        filteredVehicles = vehicles;
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

  void _filterVehicles(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredVehicles = vehicles;
      } else {
        filteredVehicles = vehicles.where((vehicle) {
          final searchLower = query.toLowerCase();
          return vehicle.brand.toLowerCase().contains(searchLower) ||
              vehicle.model.toLowerCase().contains(searchLower) ||
              vehicle.plateNumber.toLowerCase().contains(searchLower) ||
              (vehicle.vin?.toLowerCase().contains(searchLower) ?? false) ||
              vehicle.customerName.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _showAddVehicleDialog() {
    _showVehicleDialog(null);
  }

  void _showEditVehicleDialog(VehicleModel vehicle) {
    _showVehicleDialog(vehicle);
  }

  void _showVehicleDialog(VehicleModel? vehicle) {
    showDialog(
      context: context,
      builder: (context) => _VehicleDialog(
        vehicle: vehicle,
        onSave: () {
          Navigator.pop(context);
          _loadVehicles();
        },
      ),
    );
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить автомобиль?'),
        content: Text('Вы уверены, что хотите удалить ${vehicle.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await dio.delete('/api/vehicles/${vehicle.id}');
        _loadVehicles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Автомобиль удален'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openVehicleDetail(VehicleModel vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailScreen(vehicleId: vehicle.id),
      ),
    ).then((_) => _loadVehicles());
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
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚗 Автомобили',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего: ${filteredVehicles.length}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: _filterVehicles,
                    decoration: InputDecoration(
                      hintText: 'Поиск по марке, номеру, VIN...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddVehicleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить авто'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Список автомобилей
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredVehicles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty
                                  ? 'Нет автомобилей'
                                  : 'Ничего не найдено',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = filteredVehicles[index];
                          return _buildVehicleCard(vehicle);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: vehicle.needsService
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _openVehicleDetail(vehicle),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок и действия
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Редактировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Удалить', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditVehicleDialog(vehicle);
                      } else if (value == 'delete') {
                        _deleteVehicle(vehicle);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Госномер
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vehicle.plateNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Информация
              _buildInfoRow(Icons.person, vehicle.customerName),
              _buildInfoRow(Icons.speed, '${vehicle.currentMileage} км'),
              _buildInfoRow(
                Icons.local_gas_station,
                '${vehicle.fuelTypeDisplay} • ${vehicle.transmissionDisplay}',
              ),

              const Spacer(),

              // Статус ТО
              if (vehicle.needsService)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Требуется ТО',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else if (vehicle.nextServiceDate != null)
                Text(
                  'ТО через ${vehicle.daysUntilService} дней',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Диалог добавления/редактирования автомобиля
class _VehicleDialog extends StatefulWidget {
  final VehicleModel? vehicle;
  final VoidCallback onSave;

  const _VehicleDialog({
    this.vehicle,
    required this.onSave,
  });

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final dio = ApiClient().dio;

  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _colorController;
  late TextEditingController _plateNumberController;
  late TextEditingController _vinController;
  late TextEditingController _engineVolumeController;
  late TextEditingController _enginePowerController;
  late TextEditingController _mileageController;
  late TextEditingController _notesController;

  int? _selectedCustomerId;
  String _selectedFuelType = 'petrol';
  String _selectedTransmission = 'manual';
  List<Map<String, dynamic>> customers = [];
  bool isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();

    final v = widget.vehicle;
    _brandController = TextEditingController(text: v?.brand ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(text: v?.year.toString() ?? '');
    _colorController = TextEditingController(text: v?.color ?? '');
    _plateNumberController = TextEditingController(text: v?.plateNumber ?? '');
    _vinController = TextEditingController(text: v?.vin ?? '');
    _engineVolumeController = TextEditingController(text: v?.engineVolume ?? '');
    _enginePowerController = TextEditingController(text: v?.enginePower?.toString() ?? '');
    _mileageController = TextEditingController(text: v?.currentMileage.toString() ?? '0');
    _notesController = TextEditingController(text: v?.notes ?? '');

    _selectedCustomerId = v?.customerId;
    _selectedFuelType = v?.fuelType ?? 'petrol';
    _selectedTransmission = v?.transmission ?? 'manual';

    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final response = await dio.get('/api/customers');
      setState(() {
        customers = List<Map<String, dynamic>>.from(response.data);
        isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() => isLoadingCustomers = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните все обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = {
      'customerId': _selectedCustomerId,
      'brand': _brandController.text,
      'model': _modelController.text,
      'year': int.parse(_yearController.text),
      'color': _colorController.text.isEmpty ? null : _colorController.text,
      'plateNumber': _plateNumberController.text,
      'vin': _vinController.text.isEmpty ? null : _vinController.text,
      'fuelType': _selectedFuelType,
      'transmission': _selectedTransmission,
      'engineVolume': _engineVolumeController.text.isEmpty ? null : _engineVolumeController.text,
      'enginePower': _enginePowerController.text.isEmpty ? null : int.parse(_enginePowerController.text),
      'currentMileage': int.parse(_mileageController.text),
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    };

    try {
      if (widget.vehicle == null) {
        await dio.post('/api/vehicles', data: data);
      } else {
        await dio.put('/api/vehicles/${widget.vehicle!.id}', data: data);
      }
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Добавить автомобиль' : 'Редактировать автомобиль'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Владелец
                if (isLoadingCustomers)
                  const CircularProgressIndicator()
                else
                  DropdownButtonFormField<int>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(labelText: 'Владелец *'),
                    items: customers.map((customer) {
                      return DropdownMenuItem<int>(
                        value: customer['id'],
                        child: Text(customer['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCustomerId = value);
                    },
                    validator: (value) => value == null ? 'Выберите владельца' : null,
                  ),
                const SizedBox(height: 16),

                // Марка и модель
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(labelText: 'Марка *'),
                        validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(labelText: 'Модель *'),
                        validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Год и цвет
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(labelText: 'Год *'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(labelText: 'Цвет'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Госномер
                TextFormField(
                  controller: _plateNumberController,
                  decoration: const InputDecoration(labelText: 'Госномер *'),
                  validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                ),
                const SizedBox(height: 16),

                // VIN
                TextFormField(
                  controller: _vinController,
                  decoration: const InputDecoration(labelText: 'VIN'),
                ),
                const SizedBox(height: 16),

                // Топливо и КПП
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFuelType,
                        decoration: const InputDecoration(labelText: 'Топливо'),
                        items: const [
                          DropdownMenuItem(value: 'petrol', child: Text('Бензин')),
                          DropdownMenuItem(value: 'diesel', child: Text('Дизель')),
                          DropdownMenuItem(value: 'electric', child: Text('Электро')),
                          DropdownMenuItem(value: 'hybrid', child: Text('Гибрид')),
                          DropdownMenuItem(value: 'gas', child: Text('Газ')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedFuelType = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTransmission,
                        decoration: const InputDecoration(labelText: 'КПП'),
                        items: const [
                          DropdownMenuItem(value: 'manual', child: Text('Механика')),
                          DropdownMenuItem(value: 'automatic', child: Text('Автомат')),
                          DropdownMenuItem(value: 'robot', child: Text('Робот')),
                          DropdownMenuItem(value: 'cvt', child: Text('Вариатор')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTransmission = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Объем и мощность
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _engineVolumeController,
                        decoration: const InputDecoration(labelText: 'Объем (л)'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _enginePowerController,
                        decoration: const InputDecoration(labelText: 'Мощность (л.с.)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Пробег
                TextFormField(
                  controller: _mileageController,
                  decoration: const InputDecoration(labelText: 'Текущий пробег (км) *'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                ),
                const SizedBox(height: 16),

                // Примечания
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Примечания'),
                  maxLines: 3,
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
        ElevatedButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateNumberController.dispose();
    _vinController.dispose();
    _engineVolumeController.dispose();
    _enginePowerController.dispose();
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

