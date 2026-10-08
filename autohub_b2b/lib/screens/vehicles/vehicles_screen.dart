import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/screens/vehicles/vehicle_detail_screen.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/widgets/vehicle_reference_fields.dart';

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
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        setState(() {
          isForbidden = true;
          forbiddenMessage =
              (e.response?.data is Map<String, dynamic>
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
              content: Text(userFacingApiMessage(e, prefix: 'Ошибка загрузки')),
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
    await showVehicleDialog(context, vehicle: vehicle, onSave: _loadVehicles);
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
              content: Text(userFacingApiMessage(e, prefix: 'Ошибка удаления')),
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
    final wide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Автомобили',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (!isLoading && !isForbidden && !isOffline)
                          Text(
                            searchQuery.isEmpty
                                ? '${vehicles.length}'
                                : '${filteredVehicles.length} из ${vehicles.length}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (wide)
                    FilledButton.icon(
                      onPressed: _showAddVehicleDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _showAddVehicleDialog,
                      tooltip: 'Добавить',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _VehicleSearch(),
            ),
            Expanded(child: _listBody()),
          ],
        ),
      ),
    );
  }

  Widget _listBody() {
    if (isForbidden) {
      return UnauthorizedPlaceholder(
        message: forbiddenMessage,
        isForbidden: false,
      );
    }
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (isOffline) return OfflinePlaceholder(onRetry: _loadVehicles);
    if (filteredVehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                searchQuery.isEmpty ? 'Нет автомобилей' : 'Ничего не найдено',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              if (searchQuery.isEmpty) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _showAddVehicleDialog,
                  child: const Text('Добавить'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: filteredVehicles.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) => _VehicleRow(
        vehicle: filteredVehicles[index],
        onOpen: () => _openVehicleDetail(filteredVehicles[index]),
        onEdit: () => _showEditVehicleDialog(filteredVehicles[index]),
        onDelete: () => _deleteVehicle(filteredVehicles[index]),
      ),
    );
  }
}

class _VehicleSearch extends StatefulWidget {
  const _VehicleSearch();

  @override
  State<_VehicleSearch> createState() => _VehicleSearchState();
}

class _VehicleSearchState extends State<_VehicleSearch> {
  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_VehiclesScreenState>();
    return TextField(
      onChanged: screen?._filterVehicles,
      decoration: const InputDecoration(
        hintText: 'Марка, номер или VIN',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.vehicle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleModel vehicle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final service = vehicle.needsService
        ? 'Нужно ТО'
        : vehicle.nextServiceDate != null
        ? 'ТО через ${vehicle.daysUntilService} дн.'
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 12,
      title: Text(
        vehicle.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          vehicle.plateNumber,
          vehicle.customerName,
          '${vehicle.currentMileage} км',
          if (service != null) service,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: vehicle.needsService
              ? AppTheme.errorColor
              : AppTheme.textSecondary,
        ),
      ),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: 'Действия',
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Изменить')),
          PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
      ),
    );
  }
}

Future<void> showVehicleDialog(
  BuildContext context, {
  VehicleModel? vehicle,
  int? preselectedCustomerId,
  VoidCallback? onSave,
}) async {
  if (!await ensureAuthenticated(context)) return;
  if (!context.mounted) return;
  final isMobile = MediaQuery.of(context).size.width < 768;
  final dialog = VehicleDialog(
    vehicle: vehicle,
    preselectedCustomerId: preselectedCustomerId,
    onSave: () {
      Navigator.pop(context);
      onSave?.call();
    },
  );
  if (isMobile) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => dialog));
  } else {
    await showDialog(context: context, builder: (_) => dialog);
  }
}

// Диалог добавления/редактирования автомобиля
class VehicleDialog extends StatefulWidget {
  final VehicleModel? vehicle;
  final int? preselectedCustomerId;
  final VoidCallback onSave;

  const VehicleDialog({
    super.key,
    this.vehicle,
    this.preselectedCustomerId,
    required this.onSave,
  });

  @override
  State<VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<VehicleDialog> {
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

  String? selectedBrandName;
  String? selectedModelName;
  Map<String, dynamic>? selectedGeneration;

  @override
  void initState() {
    super.initState();

    final v = widget.vehicle;
    _yearController = TextEditingController(text: v?.year.toString() ?? '');
    _colorController = TextEditingController(text: v?.color ?? '');
    _plateNumberController = TextEditingController(text: v?.plateNumber ?? '');
    _vinController = TextEditingController(text: v?.vin ?? '');
    _engineVolumeController = TextEditingController(
      text: v?.engineVolume ?? '',
    );
    _enginePowerController = TextEditingController(
      text: v?.enginePower?.toString() ?? '',
    );
    _mileageController = TextEditingController(
      text: v?.currentMileage.toString() ?? '0',
    );
    _notesController = TextEditingController(text: v?.notes ?? '');

    _selectedCustomerId = v?.customerId ?? widget.preselectedCustomerId;
    _selectedFuelType = v?.fuelType ?? 'petrol';
    _selectedTransmission = v?.transmission ?? 'manual';

    // Если редактируем существующий автомобиль, пытаемся найти марку/модель в списках
    if (v != null && v.brand.isNotEmpty && v.model.isNotEmpty) {
      selectedBrandName = v.brand;
      selectedModelName = v.model;
    }

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
    if (selectedGeneration != null &&
        selectedGeneration!['year_from'] != null) {
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
      'engineVolume': _engineVolumeController.text.isEmpty
          ? null
          : _engineVolumeController.text,
      'enginePower': _enginePowerController.text.isEmpty
          ? null
          : int.parse(_enginePowerController.text),
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
            content: Text(userFacingApiMessage(e, prefix: 'Ошибка сохранения')),
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
        title: Text(
          widget.vehicle == null
              ? 'Добавить автомобиль'
              : 'Редактировать автомобиль',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
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
      title: Text(
        widget.vehicle == null
            ? 'Добавить автомобиль'
            : 'Редактировать автомобиль',
      ),
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
        ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  List<Widget> _buildFormFields() => [
    // Владелец
    if (isLoadingCustomers)
      const CircularProgressIndicator()
    else
      DropdownButtonFormField<int>(
        value: customers.any((c) => c['id'] == _selectedCustomerId)
            ? _selectedCustomerId
            : null,
        decoration: const InputDecoration(labelText: 'Владелец *'),
        items: customers.map((customer) {
          final phone = customer['phone'] as String?;
          final phoneSuffix = (phone != null && phone.isNotEmpty)
              ? ' ($phone)'
              : '';
          return DropdownMenuItem<int>(
            value: customer['id'] as int,
            child: Text('${customer['name']}$phoneSuffix'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedCustomerId = value);
        },
        validator: (value) => value == null ? 'Выберите владельца' : null,
      ),
    const SizedBox(height: 16),

    VehicleReferenceFields(
      initialMake: selectedBrandName,
      initialModel: selectedModelName,
      initialGeneration: selectedGeneration?['name'] as String?,
      onChanged: (selection) {
        setState(() {
          selectedBrandName = selection?.make;
          selectedModelName = selection?.model;
          selectedGeneration = selection?.generation == null
              ? null
              : {
                  'name': selection!.generation,
                  'year_from': selection.yearFrom,
                  'year_to': selection.yearTo,
                };
          if (selection?.yearFrom != null &&
              (_yearController.text.isEmpty || _yearController.text == '0')) {
            _yearController.text = '${selection!.yearFrom}';
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
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Обязательно' : null,
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
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Обязательно' : null,
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
