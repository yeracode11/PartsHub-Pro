import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/services/items_service.dart';
import 'package:autohub_b2b/screens/warehouse/item_detail_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class FindPartScreen extends StatefulWidget {
  const FindPartScreen({super.key});

  @override
  State<FindPartScreen> createState() => _FindPartScreenState();
}

class _FindPartScreenState extends State<FindPartScreen> with WidgetsBindingObserver {
  final ItemsService _itemsService = ItemsService();
  final MobileScannerController _scannerController = MobileScannerController();
  
  bool _isScanning = false;
  bool _hasPermission = false;
  bool _isLoading = false;
  bool _isRequestingPermission = false;
  String? _errorMessage;
  ItemModel? _foundItem;
  
  // Защита от повторных сканирований
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 3); // Минимальная задержка между сканированиями
  
  // Защита от повторных проверок доступа к камере
  bool _isCheckingCameraAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Проверяем разрешение при инициализации
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkCameraPermission();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Проверяем разрешение при каждом входе на экран
    // Это нужно, чтобы обновить состояние, если разрешение было выдано в настройках
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && !_isRequestingPermission && !_isCheckingCameraAccess) {
        _checkCameraPermissionOnly(forceCheck: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Проверяем разрешение при возврате приложения из фона (например, из настроек)
    if (state == AppLifecycleState.resumed) {
      debugPrint('FindPartScreen: App resumed, checking permission...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkCameraPermissionOnly(forceCheck: true);
        }
      });
    }
  }

  /// Проверка разрешения только через permission_handler (без запроса и диалогов)
  /// Также пробует запустить камеру напрямую для проверки реального доступа
  Future<void> _checkCameraPermissionOnly({bool forceCheck = false}) async {
    if (!mounted) return;
    
    // Если уже проверяем и не форсируем, пропускаем
    if ((_isRequestingPermission || _isCheckingCameraAccess) && !forceCheck) {
      debugPrint('FindPartScreen: Already checking permission, skipping...');
      return;
    }
    
    debugPrint('FindPartScreen: _checkCameraPermissionOnly called (forceCheck: $forceCheck)');
    
    setState(() {
      _isRequestingPermission = true;
      _isCheckingCameraAccess = true;
      _errorMessage = null;
    });
    
    try {
      // Сначала проверяем статус через permission_handler
      PermissionStatus status = await Permission.camera.status;
      debugPrint('FindPartScreen: Permission status: $status (isGranted: ${status.isGranted}, isDenied: ${status.isDenied}, isPermanentlyDenied: ${status.isPermanentlyDenied})');
      
      // Если статус показывает granted, сразу запускаем камеру
      if (status.isGranted) {
        debugPrint('FindPartScreen: Permission granted! Starting camera...');
        if (!mounted) return;
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
          _isRequestingPermission = false;
          _isCheckingCameraAccess = false;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _hasPermission) {
            debugPrint('FindPartScreen: Starting camera after permission check...');
            _startScanning();
          }
        });
        return;
      }
      
      // Если статус показывает denied, но пользователь говорит, что разрешил в настройках,
      // пробуем запустить камеру напрямую - это более надежный способ проверки
      debugPrint('FindPartScreen: Permission status shows denied, but trying to start camera directly to verify...');
      
      // Пробуем запустить камеру для проверки реального доступа
      try {
        // Останавливаем камеру, если она запущена
        try {
          await _scannerController.stop();
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (_) {}
        
        // Пробуем запустить камеру
        await _scannerController.start();
        debugPrint('FindPartScreen: Camera started successfully! Permission is actually granted.');
        
        // Если камера запустилась, значит разрешение есть
        if (!mounted) return;
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
          _isRequestingPermission = false;
          _isCheckingCameraAccess = false;
          _isScanning = true;
        });
        return;
      } catch (e) {
        debugPrint('FindPartScreen: Camera failed to start: $e');
        // Если камера не запустилась, проверяем причину
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('permission') || errorStr.contains('denied') || errorStr.contains('authorized')) {
          // Это ошибка разрешения
          debugPrint('FindPartScreen: Camera access denied');
          if (!mounted) return;
          setState(() {
            _hasPermission = false;
            _errorMessage = 'Необходимо разрешить доступ к камере в настройках приложения';
            _isRequestingPermission = false;
            _isCheckingCameraAccess = false;
          });
          // Останавливаем камеру
          try {
            await _scannerController.stop();
          } catch (_) {}
          return;
        } else {
          // Другая ошибка - возможно, камера занята или недоступна
          debugPrint('FindPartScreen: Camera error (not permission-related): $e');
          // Пробуем еще раз проверить статус
          final newStatus = await Permission.camera.status;
          if (newStatus.isGranted) {
            debugPrint('FindPartScreen: Permission status updated to granted!');
            if (!mounted) return;
            setState(() {
              _hasPermission = true;
              _errorMessage = null;
              _isRequestingPermission = false;
              _isCheckingCameraAccess = false;
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _hasPermission) {
                _startScanning();
              }
            });
          } else {
            if (!mounted) return;
            setState(() {
              _hasPermission = false;
              _errorMessage = 'Необходимо разрешить доступ к камере в настройках приложения';
              _isRequestingPermission = false;
              _isCheckingCameraAccess = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('FindPartScreen: Error checking permission: $e');
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Ошибка при проверке разрешения: $e';
        _isRequestingPermission = false;
        _isCheckingCameraAccess = false;
      });
    }
  }

  Future<void> _checkCameraPermission({bool forceCheck = false}) async {
    if (!mounted) {
      return;
    }
    
    // Если уже проверяем доступ, пропускаем
    if ((_isRequestingPermission || _isCheckingCameraAccess) && !forceCheck) {
      return;
    }
    
    debugPrint('FindPartScreen: Checking camera permission status...');
    
    setState(() {
      _isRequestingPermission = true;
      _isCheckingCameraAccess = true;
      _errorMessage = null;
    });
    
    try {
      // Проверяем статус разрешения
      PermissionStatus status = await Permission.camera.status;
      debugPrint('FindPartScreen: Permission status: $status (isGranted: ${status.isGranted}, isDenied: ${status.isDenied}, isPermanentlyDenied: ${status.isPermanentlyDenied})');
      
      if (!mounted) return;
      
      if (status.isGranted) {
        // Разрешение есть - запускаем камеру
        debugPrint('FindPartScreen: Permission granted, starting camera...');
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
          _isRequestingPermission = false;
          _isCheckingCameraAccess = false;
        });
        
        // Автоматически запускаем камеру
        if (!_isScanning) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _hasPermission && !_isScanning) {
              _startScanning();
            }
          });
        }
      } else if (status.isDenied) {
        // Разрешение еще не запрашивалось - запрашиваем через системный диалог iOS
        // Это нужно, чтобы iOS зарегистрировал запрос и добавил раздел "Камера" в настройки
        debugPrint('FindPartScreen: Permission denied, requesting...');
        status = await Permission.camera.request();
        debugPrint('FindPartScreen: Permission request result: $status');
        
        if (!mounted) return;
        
        if (status.isGranted) {
          setState(() {
            _hasPermission = true;
            _errorMessage = null;
            _isRequestingPermission = false;
            _isCheckingCameraAccess = false;
          });
          // Автоматически запускаем камеру
          if (!_isScanning) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _hasPermission && !_isScanning) {
                _startScanning();
              }
            });
          }
        } else {
          // Пользователь отклонил запрос - теперь раздел "Камера" должен появиться в настройках
          setState(() {
            _hasPermission = false;
            _errorMessage = 'Необходимо разрешить доступ к камере в настройках приложения';
            _isRequestingPermission = false;
            _isCheckingCameraAccess = false;
          });
        }
      } else {
        // Разрешение окончательно отклонено - показываем сообщение
        debugPrint('FindPartScreen: Permission permanently denied');
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Необходимо разрешить доступ к камере в настройках приложения';
          _isRequestingPermission = false;
          _isCheckingCameraAccess = false;
        });
      }
    } catch (e) {
      debugPrint('FindPartScreen: Error checking permission: $e');
      if (!mounted) return;
      
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Ошибка при проверке разрешения: $e';
        _isRequestingPermission = false;
        _isCheckingCameraAccess = false;
      });
    }
  }

  void _onBarcodeDetect(BarcodeCapture barcodeCapture) {
    // Игнорируем, если не сканируем, виджет не смонтирован, или идет загрузка
    if (!_isScanning || !mounted || _isLoading || barcodeCapture.barcodes.isEmpty) {
      return;
    }
    
    final barcode = barcodeCapture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;
    
    final code = barcode.rawValue!.trim();
    if (code.isEmpty) return;
    
    // Игнорируем только если это точно тот же код, что был недавно (в течение 1 секунды)
    // Это предотвращает множественные срабатывания на один QR-код, но позволяет сканировать разные коды
    final now = DateTime.now();
    if (_lastScannedCode == code && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!) < const Duration(seconds: 1)) {
      debugPrint('FindPartScreen: Ignoring duplicate scan of same code: $code');
      return;
    }
    
    // Сохраняем информацию о последнем сканировании
    _lastScannedCode = code;
    _lastScanTime = now;
    
    debugPrint('FindPartScreen: Processing scan of code: "$code"');
    
    // Останавливаем сканирование, чтобы не обрабатывать повторно
    _stopScanning();
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundItem = null;
    });
    
    // Ищем товар по коду
    _findItemByCode(code);
  }

  Future<void> _findItemByCode(String code) async {
    try {
      debugPrint('FindPartScreen: Searching for item with code: "$code"');
      final item = await _itemsService.findItemByCode(code);
      
      if (!mounted) return;
      
      if (item != null) {
        debugPrint('FindPartScreen: Found item - ID: ${item.id}, Name: ${item.name}, SKU: ${item.sku}');
        setState(() {
          _foundItem = item;
          _isLoading = false;
        });
        
        // Показываем информацию о найденном товаре
        _showItemDetail(item);
      } else {
        debugPrint('FindPartScreen: Item not found for code: "$code"');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Запчасть с кодом "$code" не найдена';
        });
        
        // Показываем сообщение об ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Запчасть с кодом "$code" не найдена'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Сбрасываем последний отсканированный код и возобновляем сканирование через 2 секунды
        _lastScannedCode = null;
        _lastScanTime = null;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
            _scannerController.start();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка поиска: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка поиска: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Возобновляем сканирование через 2 секунды
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
            _errorMessage = null;
          });
          _scannerController.start();
        }
      });
    }
  }

  void _showItemDetail(ItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(item: item),
      ),
    ).then((_) {
      // После возврата из детального экрана сбрасываем последний отсканированный код
      // и возобновляем сканирование через небольшую задержку
      if (mounted) {
        _lastScannedCode = null;
        _lastScanTime = null;
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _foundItem = null;
              _isLoading = false;
            });
            _scannerController.start();
          }
        });
      }
    });
  }

  void _startScanning() async {
    if (!mounted) {
      debugPrint('FindPartScreen: _startScanning skipped - not mounted');
      return;
    }
    
    // Проверяем разрешение перед запуском
    if (!_hasPermission) {
      debugPrint('FindPartScreen: No permission, checking...');
      final status = await Permission.camera.status;
      if (status.isGranted) {
        debugPrint('FindPartScreen: Permission granted, updating state...');
        setState(() {
          _hasPermission = true;
        });
      } else {
        debugPrint('FindPartScreen: Permission not granted, requesting...');
        _checkCameraPermission();
        return;
      }
    }
    
    // Если уже сканируем, не запускаем повторно
    if (_isScanning) {
      debugPrint('FindPartScreen: Already scanning, skipping start');
      return;
    }
    
    debugPrint('FindPartScreen: Starting camera...');
    
    // Сбрасываем последний отсканированный код при начале нового сканирования
    _lastScannedCode = null;
    _lastScanTime = null;
    
    if (!mounted) return;
    
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _foundItem = null;
      _isLoading = false;
    });
    
    // Запускаем камеру с обработкой ошибок
    try {
      // Сначала останавливаем камеру, если она запущена
      try {
        await _scannerController.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        // Игнорируем ошибки при остановке
      }
      
      await _scannerController.start();
      debugPrint('FindPartScreen: Camera started successfully');
      
      // Убеждаемся, что состояние обновлено
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    } catch (e) {
      debugPrint('FindPartScreen: Error starting camera: $e');
      
      // Если ошибка "already started", камера уже работает - это нормально
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('already started')) {
        debugPrint('FindPartScreen: Camera already started, continuing...');
        if (mounted) {
          setState(() {
            _isScanning = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _errorMessage = 'Ошибка запуска камеры: $e';
          });
        }
      }
    }
  }

  void _stopScanning() {
    if (!mounted) return;
    
    setState(() {
      _isScanning = false;
    });
    
    _scannerController.stop();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Найти запчасть'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScanning,
              tooltip: 'Остановить сканирование',
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startScanning,
              tooltip: 'Начать сканирование',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Проверяем разрешение при каждом построении UI, если оно еще не проверено
    if (!_hasPermission && !_isRequestingPermission && !_isCheckingCameraAccess) {
      // Запускаем проверку в фоне
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkCameraPermissionOnly(forceCheck: true);
        }
      });
    }
    
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'Необходимо разрешить доступ к камере в настройках приложения',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Если раздел "Камера" не появляется в настройках:\n'
                '1. Удалите приложение с устройства\n'
                '2. Переустановите приложение\n'
                '3. При первом запуске нажмите "Запросить доступ к камере"',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  debugPrint('FindPartScreen: Requesting camera permission via mobile_scanner...');
                  
                  // Пробуем запустить камеру через mobile_scanner - это может показать системный диалог iOS
                  try {
                    setState(() {
                      _isRequestingPermission = true;
                    });
                    
                    // Пробуем запустить камеру - это должно показать системный диалог iOS
                    await _scannerController.start();
                    await Future.delayed(const Duration(milliseconds: 500));
                    
                    // Проверяем статус разрешения после попытки запуска
                    final status = await Permission.camera.status;
                    debugPrint('FindPartScreen: Permission status after scanner start: $status');
                    
                    if (status.isGranted) {
                      if (mounted) {
                        setState(() {
                          _hasPermission = true;
                          _errorMessage = null;
                          _isRequestingPermission = false;
                        });
                        // Камера уже запущена, просто обновляем состояние
                        setState(() {
                          _isScanning = true;
                        });
                      }
                    } else {
                      // Останавливаем камеру, если разрешения нет
                      await _scannerController.stop();
                      if (mounted) {
                        setState(() {
                          _hasPermission = false;
                          _errorMessage = 'Разрешите доступ к камере в настройках приложения';
                          _isRequestingPermission = false;
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint('FindPartScreen: Error requesting permission: $e');
                    try {
                      await _scannerController.stop();
                    } catch (_) {}
                    
                    // Проверяем статус разрешения
                    final status = await Permission.camera.status;
                    debugPrint('FindPartScreen: Permission status after error: $status');
                    
                    if (mounted) {
                      if (status.isGranted) {
                        setState(() {
                          _hasPermission = true;
                          _errorMessage = null;
                          _isRequestingPermission = false;
                        });
                        // Запускаем камеру
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted && _hasPermission && !_isScanning) {
                            _startScanning();
                          }
                        });
                      } else {
                        setState(() {
                          _hasPermission = false;
                          _errorMessage = 'Разрешите доступ к камере в настройках приложения';
                          _isRequestingPermission = false;
                        });
                      }
                    }
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Запросить доступ к камере'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  debugPrint('FindPartScreen: Opening app settings...');
                  await openAppSettings();
                  // Проверяем разрешение после возврата из настроек
                  // Используем более длительную задержку, чтобы дать время iOS обновить статус
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      debugPrint('FindPartScreen: Rechecking permission after returning from settings...');
                      _checkCameraPermissionOnly(forceCheck: true);
                    }
                  });
                },
                icon: const Icon(Icons.settings),
                label: const Text('Открыть настройки'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Поиск запчасти...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Камера - всегда показываем, но контролируем через controller
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeDetect,
          errorBuilder: (context, error, child) {
            debugPrint('FindPartScreen: MobileScanner error: $error');
            return Container(
              color: Colors.black,
              child: Center(
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
                      'Ошибка камеры: $error',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startScanning,
                      child: const Text('Попробовать снова'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        // Оверлей с инструкцией
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isScanning)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Нажмите кнопку для начала сканирования',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Наведите камеру на QR-код',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'QR-код будет отсканирован автоматически',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Рамка для сканирования (опционально)
        if (_isScanning)
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

