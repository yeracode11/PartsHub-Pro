import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
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
  bool isForbidden = false;
  String? forbiddenMessage;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      isLoading = true;
      isForbidden = false;
      isOffline = false;
    });

    try {
      final response = await dio.get('/api/vehicles');
      final List<dynamic> data = response.data;

      setState(() {
        vehicles = data.map((json) => VehicleModel.fromJson(json)).toList();
        filteredVehicles = vehicles;
        isLoading = false;
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() {
          isForbidden = true;
          forbiddenMessage = (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к разделу «Автомобили». Войдите под владельцем или менеджером.';
          isLoading = false;
        });
      } else if (isNetworkError(e)) {
        setState(() {
          isOffline = true;
          isLoading = false;
        });
      } else {
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

  Future<void> _showVehicleDialog(VehicleModel? vehicle) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final dialog = _VehicleDialog(
      vehicle: vehicle,
      onSave: () {
        Navigator.pop(context);
        _loadVehicles();
      },
    );
    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => dialog),
      );
    } else {
      showDialog(context: context, builder: (_) => dialog);
    }
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final confirm = await DialogHelper.showConfirmSimple(
      context: context,
      title: 'Удалить автомобиль?',
      message: 'Вы уверены, что хотите удалить ${vehicle.displayName}?',
      confirmText: 'Удалить',
      isDestructive: true,
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
            child: isForbidden
                ? UnauthorizedPlaceholder(message: forbiddenMessage)
                : isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : isOffline
                    ? OfflinePlaceholder(onRetry: _loadVehicles)
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

  // Kolesa.kz данные
  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> models = [];
  List<Map<String, dynamic>> generations = [];
  
  String? selectedBrandSlug;
  String? selectedBrandName;
  String? selectedModelSlug;
  String? selectedModelName;
  Map<String, dynamic>? selectedGeneration;
  
  bool isLoadingBrands = false;
  bool isLoadingModels = false;
  bool isLoadingGenerations = false;

  @override
  void initState() {
    super.initState();

    final v = widget.vehicle;
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

    // Если редактируем существующий автомобиль, пытаемся найти марку/модель в списках
    if (v != null && v.brand.isNotEmpty && v.model.isNotEmpty) {
      selectedBrandName = v.brand;
      selectedModelName = v.model;
    }

    _loadCustomers();
    _loadBrands();
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

  Future<void> _loadBrands() async {
    setState(() => isLoadingBrands = true);
    try {
      final res = await dio.get('/api/auto-data/brands');
      final data = res.data;
      
      if (mounted) {
        setState(() {
          // Проверяем, что данные есть и это массив
          if (data != null && data is List) {
            brands = List<Map<String, dynamic>>.from(data);
          } else {
            brands = [];
            if (data != null) {
            }
          }
          
          // Если редактируем и есть марка, пытаемся найти её в списке
          if (widget.vehicle != null && widget.vehicle!.brand.isNotEmpty && brands.isNotEmpty) {
            try {
              final foundBrand = brands.firstWhere(
                (b) => (b['name'] as String).toLowerCase() == widget.vehicle!.brand.toLowerCase(),
                orElse: () => {},
              );
              if (foundBrand.isNotEmpty) {
                selectedBrandSlug = foundBrand['slug'] as String;
                selectedBrandName = foundBrand['name'] as String;
                _loadModels(selectedBrandSlug!);
              }
            } catch (e) {
            }
          }
        });
        
        if (brands.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Марки не загружены. Проверьте подключение к серверу.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          brands = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки марок: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingBrands = false);
    }
  }

  Future<void> _loadModels(String brandSlug) async {
    setState(() {
      isLoadingModels = true;
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
        // Если редактируем и есть модель, пытаемся найти её в списке
        if (widget.vehicle != null && widget.vehicle!.model.isNotEmpty) {
          final foundModel = models.firstWhere(
            (m) => (m['name'] as String).toLowerCase() == widget.vehicle!.model.toLowerCase(),
            orElse: () => {},
          );
          if (foundModel.isNotEmpty) {
            selectedModelSlug = foundModel['slug'] as String;
            selectedModelName = foundModel['name'] as String;
            _loadGenerations(brandSlug, selectedModelSlug!);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки моделей: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingModels = false);
    }
  }

  Future<void> _loadGenerations(String brandSlug, String modelSlug) async {
    setState(() {
      isLoadingGenerations = true;
      generations = [];
      selectedGeneration = null;
    });
    try {
      final res = await dio.get('/api/auto-data/brands/$brandSlug/models/$modelSlug/generations');
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
      if (mounted) setState(() => isLoadingGenerations = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || 
        _selectedCustomerId == null ||
        (selectedBrandName == null || selectedBrandName!.isEmpty) ||
        (selectedModelName == null || selectedModelName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните все обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Определяем год из поколения или из поля
    int year;
    if (selectedGeneration != null && selectedGeneration!['year_from'] != null) {
      year = selectedGeneration!['year_from'] as int;
    } else {
      year = int.parse(_yearController.text);
    }

    final data = {
      'customerId': _selectedCustomerId,
      'brand': selectedBrandName!.trim(),
      'model': selectedModelName!.trim(),
      'year': year,
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) return _buildMobileLayout(context);
    return _buildDesktopDialog(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Добавить автомобиль' : 'Редактировать автомобиль'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildFormFields(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDialog(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Добавить автомобиль' : 'Редактировать автомобиль'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildFormFields(),
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

  List<Widget> _buildFormFields() => [
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

                // Марка
                if (isLoadingBrands)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: selectedBrandSlug,
                    decoration: const InputDecoration(labelText: 'Марка *'),
                    hint: const Text('Выберите марку'),
                    items: brands.map((brand) {
                      return DropdownMenuItem<String>(
                        value: brand['slug'] as String,
                        child: Text(brand['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedBrandSlug = value;
                        selectedBrandName = brands.firstWhere((b) => b['slug'] == value)['name'] as String;
                        models = [];
                        generations = [];
                        selectedModelSlug = null;
                        selectedModelName = null;
                        selectedGeneration = null;
                      });
                      _loadModels(value);
                    },
                    validator: (value) => value == null ? 'Выберите марку' : null,
                  ),
                const SizedBox(height: 16),

                // Модель
                if (selectedBrandSlug == null)
                  const SizedBox.shrink()
                else if (isLoadingModels)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: selectedModelSlug,
                    decoration: const InputDecoration(labelText: 'Модель *'),
                    hint: const Text('Выберите модель'),
                    items: models.map((model) {
                      return DropdownMenuItem<String>(
                        value: model['slug'] as String,
                        child: Text(model['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null || selectedBrandSlug == null) return;
                      setState(() {
                        selectedModelSlug = value;
                        selectedModelName = models.firstWhere((m) => m['slug'] == value)['name'] as String;
                        generations = [];
                        selectedGeneration = null;
                      });
                      _loadGenerations(selectedBrandSlug!, value);
                    },
                    validator: (value) => value == null ? 'Выберите модель' : null,
                  ),
                const SizedBox(height: 16),

                // Поколение
                if (selectedModelSlug == null)
                  const SizedBox.shrink()
                else if (isLoadingGenerations)
                  const LinearProgressIndicator()
                else if (generations.isEmpty)
                  const SizedBox.shrink()
                else
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedGeneration,
                    decoration: const InputDecoration(labelText: 'Поколение'),
                    hint: const Text('Выберите поколение (необязательно)'),
                    items: generations.map((gen) {
                      final yearFrom = gen['year_from'] as int?;
                      final yearTo = gen['year_to'] as int?;
                      final yearText = yearFrom != null
                          ? ' (${yearFrom}${yearTo != null ? '–$yearTo' : '–н.в.'})'
                          : '';
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: gen,
                        child: Text('${gen['name']}$yearText'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedGeneration = value;
                        // Автоматически заполняем год из поколения, если поле пустое
                        if (value != null && value['year_from'] != null) {
                          final yearFrom = value['year_from'] as int;
                          if (_yearController.text.isEmpty || _yearController.text == '0') {
                            _yearController.text = yearFrom.toString();
                          }
                        }
                      });
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
              ];

  @override
  void dispose() {
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


