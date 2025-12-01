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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок и поиск
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🚗 Автомобили',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 20 : 24,
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
                    if (!isMobile)
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
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _showAddVehicleDialog,
                        tooltip: 'Добавить авто',
                      ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: _filterVehicles,
                        decoration: InputDecoration(
                          hintText: 'Поиск по марке, номеру, VIN...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isMobile ? 12 : 16,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = isMobile ? 1 : 3;
                          // Увеличиваем aspectRatio для мобильных, чтобы карточки были выше
                          final aspectRatio = isMobile ? 1.3 : 1.5;
                          
                          return GridView.builder(
                            padding: EdgeInsets.all(padding),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: aspectRatio,
                              crossAxisSpacing: isMobile ? 0 : 16,
                              mainAxisSpacing: isMobile ? 12 : 16,
                            ),
                            itemCount: filteredVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = filteredVehicles[index];
                              return _buildVehicleCard(vehicle);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
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
          padding: EdgeInsets.all(isMobile ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок и действия
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.displayName,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    iconSize: isMobile ? 18 : 24,
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
              SizedBox(height: isMobile ? 4 : 8),

              // Госномер
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12,
                  vertical: isMobile ? 3 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vehicle.plateNumber,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 16,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 6 : 12),

              // Информация
              _buildInfoRow(Icons.person, vehicle.customerName, isMobile: isMobile),
              SizedBox(height: isMobile ? 1 : 4),
              _buildInfoRow(Icons.speed, '${vehicle.currentMileage} км', isMobile: isMobile),
              SizedBox(height: isMobile ? 1 : 4),
              _buildInfoRow(
                Icons.local_gas_station,
                '${vehicle.fuelTypeDisplay} • ${vehicle.transmissionDisplay}',
                isMobile: isMobile,
              ),

              SizedBox(height: isMobile ? 6 : 12),

              // Статус ТО
              if (vehicle.needsService)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: isMobile ? 14 : 16, color: Colors.orange.shade700),
                      SizedBox(width: isMobile ? 3 : 4),
                      Text(
                        'Требуется ТО',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 11 : 12,
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
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isMobile = false}) {
    return Row(
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: AppTheme.textSecondary),
        SizedBox(width: isMobile ? 6 : 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  Future<void> _openKolesaSelector() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _KolesaVehicleSelectorDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _brandController.text = result['brandName'] ?? _brandController.text;
        _modelController.text = result['modelName'] ?? _modelController.text;
        if (result['yearFrom'] != null && (_yearController.text.isEmpty || _yearController.text == '0')) {
          _yearController.text = (result['yearFrom'] as int).toString();
        }
        // VIN/другие поля здесь не задаём, Kolesa их не возвращает
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Добавить автомобиль' : 'Редактировать автомобиль'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 768
            ? MediaQuery.of(context).size.width * 0.9
            : 600,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    
                    if (isMobile) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _brandController,
                            decoration: const InputDecoration(labelText: 'Марка *'),
                            validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _modelController,
                            decoration: const InputDecoration(labelText: 'Модель *'),
                            validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _openKolesaSelector,
                              icon: const Icon(Icons.search),
                              label: const Text('Подобрать с Kolesa.kz'),
                            ),
                          ),
                        ],
                      );
                    }
                    
                    return Row(
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
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Подобрать с Kolesa.kz',
                          icon: const Icon(Icons.search),
                          onPressed: _openKolesaSelector,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Год и цвет
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    
                    if (isMobile) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _yearController,
                            decoration: const InputDecoration(labelText: 'Год *'),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty ?? true ? 'Обязательно' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _colorController,
                            decoration: const InputDecoration(labelText: 'Цвет'),
                          ),
                        ],
                      );
                    }
                    
                    return Row(
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
                    );
                  },
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    
                    if (isMobile) {
                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
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
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
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
                        ],
                      );
                    }
                    
                    return Row(
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
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Объем и мощность
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    
                    if (isMobile) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _engineVolumeController,
                            decoration: const InputDecoration(labelText: 'Объем (л)'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _enginePowerController,
                            decoration: const InputDecoration(labelText: 'Мощность (л.с.)'),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      );
                    }
                    
                    return Row(
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
                    );
                  },
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

/// Диалог выбора автомобиля с Kolesa.kz: Марка → Модель → Поколение
class _KolesaVehicleSelectorDialog extends StatefulWidget {
  const _KolesaVehicleSelectorDialog({super.key});

  @override
  State<_KolesaVehicleSelectorDialog> createState() => _KolesaVehicleSelectorDialogState();
}

class _KolesaVehicleSelectorDialogState extends State<_KolesaVehicleSelectorDialog> {
  final Dio dio = ApiClient().dio;

  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> models = [];
  List<Map<String, dynamic>> generations = [];

  String? selectedBrandSlug;
  String? selectedBrandName;
  String? selectedModelSlug;
  String? selectedModelName;
  Map<String, dynamic>? selectedGeneration;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => isLoading = true);
    try {
      final res = await dio.get('/api/auto-data/brands');
      setState(() {
        brands = List<Map<String, dynamic>>.from(res.data ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки марок: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadModels(String brandSlug) async {
    setState(() {
      isLoading = true;
      models = [];
      generations = [];
      selectedModelSlug = null;
      selectedModelName = null;
      selectedGeneration = null;
    });
    try {
      final res = await dio.get('/api/auto-data/brands/$brandSlug/models');
      setState(() {
        models = List<Map<String, dynamic>>.from(res.data ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки моделей: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadGenerations(String brandSlug, String modelSlug) async {
    setState(() {
      isLoading = true;
      generations = [];
      selectedGeneration = null;
    });
    try {
      final res = await dio.get(
        '/api/auto-data/brands/$brandSlug/models/$modelSlug/generations',
      );
      setState(() {
        generations = List<Map<String, dynamic>>.from(res.data ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки поколений: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AlertDialog(
      title: const Text('Подбор авто (Kolesa.kz)'),
      content: SizedBox(
        width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            // Марка
            DropdownButtonFormField<String>(
              value: selectedBrandSlug,
              decoration: const InputDecoration(labelText: 'Марка'),
              items: brands
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: b['slug'] as String,
                      child: Text(b['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedBrandSlug = value;
                  selectedBrandName = brands
                      .firstWhere(
                        (b) => b['slug'] == value,
                        orElse: () => {'name': value},
                      )['name'] as String?;
                });
                _loadModels(value);
              },
            ),
            const SizedBox(height: 12),
            // Модель
            DropdownButtonFormField<String>(
              value: selectedModelSlug,
              decoration: const InputDecoration(labelText: 'Модель'),
              items: models
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m['slug'] as String,
                      child: Text(m['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || selectedBrandSlug == null) return;
                setState(() {
                  selectedModelSlug = value;
                  selectedModelName = models
                      .firstWhere(
                        (m) => m['slug'] == value,
                        orElse: () => {'name': value},
                      )['name'] as String?;
                });
                _loadGenerations(selectedBrandSlug!, value);
              },
            ),
            const SizedBox(height: 12),
            // Поколение
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedGeneration,
              decoration: const InputDecoration(labelText: 'Поколение'),
              items: generations
                  .map(
                    (g) => DropdownMenuItem<Map<String, dynamic>>(
                      value: g,
                      child: Text(
                        '${g['name']}'
                        ' (${g['year_from'] ?? '-'}'
                        '${g['year_to'] != null ? '–${g['year_to']}' : '–н.в.'})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedGeneration = value;
                });
              },
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
          onPressed: selectedBrandSlug != null && selectedModelSlug != null
              ? () {
                  Navigator.pop<Map<String, dynamic>>(context, {
                    'brandSlug': selectedBrandSlug,
                    'brandName': selectedBrandName,
                    'modelSlug': selectedModelSlug,
                    'modelName': selectedModelName,
                    'generation': selectedGeneration,
                    'yearFrom': selectedGeneration?['year_from'],
                    'yearTo': selectedGeneration?['year_to'],
                  });
                }
              : null,
          child: const Text('Выбрать'),
        ),
      ],
    );
  }
}

