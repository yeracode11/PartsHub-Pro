import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/service_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/services_api_service.dart';
import '../../services/vehicles_api_service.dart';
import '../../services/api_client.dart';

class BookAppointmentScreen extends StatefulWidget {
  final AutoService service;

  const BookAppointmentScreen({
    super.key,
    required this.service,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final ServicesApiService _servicesApiService = ServicesApiService(ApiClient());
  final VehiclesApiService _vehiclesApiService = VehiclesApiService(ApiClient());
  
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  String? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  bool _isLoading = false;
  bool _isLoadingTimeSlots = false;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });
    
    try {
      final vehicles = await _vehiclesApiService.getUserVehicles();
      setState(() {
        _vehicles = vehicles;
        if (vehicles.isNotEmpty) {
          _selectedVehicle = vehicles.first;
        }
        _isLoadingVehicles = false;
      });
    } catch (e) {
      // Если API недоступен, используем моковые данные для демонстрации
      print('API недоступен, используем моковые данные: $e');
      final mockVehicles = [
        Vehicle(
          id: 1,
          brand: 'Toyota',
          model: 'Camry',
          year: 2020,
          vin: '1HGBH41JXMN109186',
          plateNumber: '123ABC01',
          color: 'Белый',
          fuelType: FuelType.petrol,
          transmission: TransmissionType.automatic,
          engineVolume: '2.5L',
          currentMileage: 45000,
          lastServiceDate: DateTime.now().subtract(const Duration(days: 30)),
          nextServiceDate: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now().subtract(const Duration(days: 365)),
          updatedAt: DateTime.now(),
        ),
        Vehicle(
          id: 2,
          brand: 'BMW',
          model: 'X5',
          year: 2019,
          vin: 'WBAFR9C50BC123456',
          plateNumber: '456DEF02',
          color: 'Черный',
          fuelType: FuelType.petrol,
          transmission: TransmissionType.automatic,
          engineVolume: '3.0L',
          currentMileage: 62000,
          lastServiceDate: DateTime.now().subtract(const Duration(days: 15)),
          nextServiceDate: DateTime.now().add(const Duration(days: 45)),
          createdAt: DateTime.now().subtract(const Duration(days: 730)),
          updatedAt: DateTime.now(),
        ),
      ];
      
      setState(() {
        _vehicles = mockVehicles;
        if (mockVehicles.isNotEmpty) {
          _selectedVehicle = mockVehicles.first;
        }
        _isLoadingVehicles = false;
      });
    }
  }

  Future<void> _loadTimeSlots() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoadingTimeSlots = true;
    });

    try {
      final timeSlots = await _servicesApiService.getAvailableTimeSlots(
        widget.service.id,
        _selectedDate!,
      );
      setState(() {
        _availableTimeSlots = timeSlots;
        _isLoadingTimeSlots = false;
        if (timeSlots.isNotEmpty) {
          _selectedTimeSlot = timeSlots.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingTimeSlots = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadTimeSlots();
    }
  }

  Future<void> _submitAppointment() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVehicle == null || _selectedService == null || _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пожалуйста, заполните все поля для записи.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final estimatedPrice = widget.service.servicePrices[_selectedService!] ?? 0.0;
        
        await _servicesApiService.createAppointment(
          serviceId: widget.service.id,
          userId: 'user1', // Получение userId из auth service будет реализовано позже
          vehicleId: _selectedVehicle!.id.toString(),
          serviceName: _selectedService!,
          appointmentDate: _selectedDate!,
          timeSlot: _selectedTimeSlot ?? '10:00',
          notes: _notesController.text,
          estimatedPrice: estimatedPrice,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запись успешно создана!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при создании записи: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Запись на сервис'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingVehicles
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'У вас нет добавленных автомобилей.\nПожалуйста, добавьте автомобиль в профиле.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Информация о сервисе
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'СТО: ${widget.service.name}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Адрес: ${widget.service.address}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Телефон: ${widget.service.phone}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Выбор автомобиля
                        Text(
                          'Выберите автомобиль:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Vehicle>(
                          initialValue: _selectedVehicle,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _vehicles.map((vehicle) {
                            return DropdownMenuItem(
                              value: vehicle,
                              child: Text('${vehicle.brand} ${vehicle.model} (${vehicle.year})'),
                            );
                          }).toList(),
                          onChanged: (vehicle) {
                            setState(() {
                              _selectedVehicle = vehicle;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Выберите автомобиль';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Выбор услуги
                        Text(
                          'Выберите услугу:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedService,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: widget.service.services.map((service) {
                            final price = widget.service.servicePrices[service] ?? 0.0;
                            return DropdownMenuItem(
                              value: service,
                              child: Text('$service - ${price.toStringAsFixed(0)} ₸'),
                            );
                          }).toList(),
                          onChanged: (service) {
                            setState(() {
                              _selectedService = service;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Выберите услугу';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Выбор даты
                        Text(
                          'Выберите дату:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(
                                text: _selectedDate == null
                                    ? ''
                                    : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}',
                              ),
                              decoration: InputDecoration(
                                hintText: 'Выберите дату',
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Выберите дату';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Дополнительные примечания
                        Text(
                          'Дополнительные примечания:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Опишите проблему или пожелания...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Кнопка записи
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Записаться на сервис',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}