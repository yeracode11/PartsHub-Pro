import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen>
    with SingleTickerProviderStateMixin {
  final dio = ApiClient().dio;
  late TabController _tabController;

  bool isLoading = true;
  bool isWhatsAppReady = false;
  String? qrCode;
  String? statusMessage;

  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> customers = [];
  Set<int> selectedCustomers = {};
  
  List<Map<String, dynamic>> messageHistory = [];
  Map<String, dynamic>? historyStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    
    // Периодически проверяем статус WhatsApp (каждые 10 секунд)
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        // Если пользователь на вкладке "Рассылка", обновляем статус
        _checkWhatsAppStatus();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);

    try {
      // Проверяем статус WhatsApp
      await _checkWhatsAppStatus();

      // Загружаем шаблоны
      await _loadTemplates();

      // Загружаем клиентов
      await _loadCustomers();

      // Загружаем историю
      await _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkWhatsAppStatus() async {
    try {
      final response = await dio.get('/api/whatsapp/status');
      final ready = response.data['ready'] ?? false;
      final needsAuth = response.data['needsAuth'] ?? false;
      
      print('📱 WhatsApp Status: ready=$ready, needsAuth=$needsAuth');
      
      setState(() {
        isWhatsAppReady = ready;
        statusMessage = response.data['message'];
      });

      // Если требуется авторизация, получаем QR код
      if (!ready && needsAuth) {
        final qrResponse = await dio.get('/api/whatsapp/qr');
        final qrData = qrResponse.data['qrCode'];
        print('📲 QR Code received: ${qrData != null ? "Yes" : "No"}');
        setState(() {
          qrCode = qrData;
        });
      } else {
        setState(() {
          qrCode = null;
        });
      }
    } catch (e) {
      print('❌ Error checking WhatsApp status: $e');
    }
  }

  Future<void> _reconnectWhatsApp() async {
    try {
      // Показываем диалог прогресса
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Переподключение WhatsApp...'),
            ],
          ),
        ),
      );

      await dio.post('/api/whatsapp/reconnect');
      
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp переподключен'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Обновляем статус
        await _checkWhatsAppStatus();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка переподключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logoutWhatsApp() async {
    // Подтверждение выхода
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из WhatsApp'),
        content: const Text(
          'Вы уверены, что хотите выйти из WhatsApp? Вам потребуется снова отсканировать QR код для авторизации.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Показываем диалог прогресса
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Выход из WhatsApp...'),
            ],
          ),
        ),
      );

      await dio.post('/api/whatsapp/logout');
      
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Вы успешно вышли из WhatsApp'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Сбрасываем состояние
        setState(() {
          isWhatsAppReady = false;
          qrCode = null;
          statusMessage = 'Требуется авторизация';
        });
        
        // Обновляем статус (это создаст новую сессию и покажет QR код)
        await _checkWhatsAppStatus();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выхода: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка переподключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshQr() async {
    try {
      final qrResponse = await dio.get('/api/whatsapp/qr');
      final qrData = qrResponse.data['qrCode'];
      setState(() {
        qrCode = qrData;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось обновить QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final response = await dio.get('/api/whatsapp/templates');
      setState(() {
        templates = List<Map<String, dynamic>>.from(response.data);
      });
    } catch (e) {
      print('Error loading templates: $e');
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final response = await dio.get('/api/customers');
      setState(() {
        customers = List<Map<String, dynamic>>.from(response.data)
            .where((c) => c['phone'] != null && c['phone'].toString().isNotEmpty)
            .toList();
      });
      print('✅ Loaded ${customers.length} customers with phone numbers');
    } catch (e) {
      print('❌ Error loading customers: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final [historyResponse, statsResponse] = await Future.wait([
        dio.get('/api/whatsapp/history?limit=50'),
        dio.get('/api/whatsapp/history/stats?period=30d'),
      ]);

      setState(() {
        messageHistory = List<Map<String, dynamic>>.from(
          historyResponse.data['items'],
        );
        historyStats = statsResponse.data;
      });
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _createDefaultTemplates() async {
    try {
      await dio.post('/api/whatsapp/templates/create-defaults');
      await _loadTemplates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Шаблоны по умолчанию созданы'),
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

  Future<void> _sendBulkMessages(String template) async {
    if (selectedCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите получателей'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Формируем список получателей
    final recipients = customers
        .where((c) => selectedCustomers.contains(c['id']))
        .map((c) => {
              'phone': c['phone'],
              'name': c['name'],
              'customerId': c['id'],
            })
        .toList();

    try {
      // Показываем диалог прогресса
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Отправка сообщений...'),
            ],
          ),
        ),
      );

      final response = await dio.post(
        '/api/whatsapp/send-bulk',
        data: {
          'recipients': recipients,
          'template': template,
          'delayMs': 5000, // 5 секунд между сообщениями
        },
      );

      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса

        final sent = response.data['sent'] ?? 0;
        final failed = response.data['failed'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Отправлено: $sent, Ошибок: $failed',
            ),
            backgroundColor: failed > 0 ? Colors.orange : Colors.green,
          ),
        );

        // Очищаем выбор
        setState(() {
          selectedCustomers.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Заголовок и статус
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF25D366),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp Рассылка',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isWhatsAppReady
                                ? Colors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusMessage ?? 'Загрузка...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isWhatsAppReady && qrCode != null)
                ElevatedButton.icon(
                  onPressed: () => _showQRDialog(),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Авторизация'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              if (!isWhatsAppReady)
                ElevatedButton.icon(
                  onPressed: _reconnectWhatsApp,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Переподключить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isWhatsAppReady)
                ElevatedButton.icon(
                  onPressed: _logoutWhatsApp,
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadInitialData,
                tooltip: 'Обновить',
              ),
            ],
          ),
        ),

        // Табы
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.send), text: 'Рассылка'),
            Tab(icon: Icon(Icons.text_snippet), text: 'Шаблоны'),
            Tab(icon: Icon(Icons.history), text: 'История'),
          ],
        ),

        // Контент
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSendTab(),
              _buildTemplatesTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendTab() {
    return Row(
      children: [
        // Список клиентов
        Expanded(
          flex: 2,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Получатели (${selectedCustomers.length} выбрано)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedCustomers = customers
                                    .map<int>((c) => c['id'] as int)
                                    .toSet();
                              });
                            },
                            child: const Text('Выбрать все'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedCustomers.clear();
                              });
                            },
                            child: const Text('Снять все'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: customers.isEmpty
                      ? Center(
                          child: Text(
                            'Нет клиентов',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            final isSelected =
                                selectedCustomers.contains(customer['id']);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedCustomers.add(customer['id']);
                                  } else {
                                    selectedCustomers.remove(customer['id']);
                                  }
                                });
                              },
                              title: Text(customer['name']),
                              subtitle: Text(customer['phone'] ?? 'Нет телефона'),
                              secondary: CircleAvatar(
                                backgroundColor:
                                    AppTheme.primaryColor.withOpacity(0.1),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Выбор шаблона и отправка
        Expanded(
          flex: 1,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Шаблоны сообщений',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (templates.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.text_snippet_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text('Нет шаблонов'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _createDefaultTemplates,
                            child: const Text('Создать шаблоны'),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final canSend = isWhatsAppReady && selectedCustomers.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(template['name']),
                              subtitle: Text(
                                template['content'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 120,
                                child: ElevatedButton(
                                  onPressed: canSend
                                      ? () {
                                          print('🚀 Sending bulk: ready=$isWhatsAppReady, selected=${selectedCustomers.length}');
                                          _sendBulkMessages(template['content']);
                                        }
                                      : null,
                                  child: Text(
                                    !isWhatsAppReady 
                                      ? 'WA не готов' 
                                      : selectedCustomers.isEmpty 
                                        ? 'Выберите' 
                                        : 'Отправить',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Редактор шаблонов в разработке',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Статистика
        if (historyStats != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard(
                  'Всего отправлено',
                  historyStats!['total'].toString(),
                  Icons.send,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Успешно',
                  historyStats!['sent'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Ошибок',
                  historyStats!['failed'].toString(),
                  Icons.error,
                  Colors.red,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Успешность',
                  '${historyStats!['successRate']}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        // Список истории
        Expanded(
          child: messageHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'История пуста',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messageHistory.length,
                  itemBuilder: (context, index) {
                    final message = messageHistory[index];
                    final isSent = message['status'] == 'sent';
                    final date = DateTime.parse(message['sentAt']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSent
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          child: Icon(
                            isSent ? Icons.check : Icons.error_outline,
                            color: isSent ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(message['phone']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['message'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd.MM.yyyy HH:mm').format(date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                if (message['isBulk'] == true) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      message['campaignName'] ?? 'Рассылка',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: isSent
                            ? const Icon(Icons.done_all, color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Ошибка отправки'),
                                      content: Text(
                                        message['errorMessage'] ??
                                            'Неизвестная ошибка',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Закрыть'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Авторизация WhatsApp'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Откройте WhatsApp на телефоне:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Перейдите в Настройки → Связанные устройства'),
                      SizedBox(height: 4),
                      Text('2. Нажмите "Связать устройство"'),
                      SizedBox(height: 4),
                      Text('3. Отсканируйте этот QR код:'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (qrCode != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrCode!,
                      version: QrVersions.auto,
                      size: 360.0,
                      gapless: false,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'После сканирования нажмите "Проверить статус"',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: _refreshQr,
            child: const Text('Обновить QR'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _checkWhatsAppStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Проверить статус'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

