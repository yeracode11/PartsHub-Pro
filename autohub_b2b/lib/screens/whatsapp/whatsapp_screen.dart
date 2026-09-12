import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_templates_tab.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

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
  bool isForbidden = false;
  bool _isOffline = false;
  bool _isCheckingStatus = false;
  String? qrCode;
  String? qrUrl;
  String? statusMessage;
  String? forbiddenMessage;

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

    _tabController.addListener(() {
      if (_tabController.index == 0 && !_isCheckingStatus) {
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
    setState(() {
      isLoading = true;
      _isOffline = false;
    });

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
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        if (mounted) {
          setState(() {
            isForbidden = true;
            forbiddenMessage =
                (e.response?.data is Map<String, dynamic>
                    ? (e.response?.data['message'] as String?)
                    : null) ??
                'У вас нет доступа к модулю WhatsApp. Войдите под владельцем или менеджером.';
          });
        }
      } else if (isNetworkError(e)) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingApiMessage(e, prefix: 'Ошибка загрузки данных')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkWhatsAppStatus() async {
    if (_isCheckingStatus) return;
    _isCheckingStatus = true;
    try {
      final response = await dio.get('/api/whatsapp/status');
      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final ready = data['ready'] ?? false;
      final needsAuth = data['needsAuth'] ?? false;
      final message = data['message']?.toString();

      if (!mounted) return;
      setState(() {
        isWhatsAppReady = ready;
        statusMessage = message ?? statusMessage;
      });

      // Если требуется авторизация, получаем QR код или ссылку
      if (!ready && needsAuth) {
        final qrResponse = await dio.get('/api/whatsapp/qr');
        final qrData = qrResponse.data is Map
            ? qrResponse.data as Map<String, dynamic>
            : <String, dynamic>{};
        final u = (qrData['qrUrl'] ?? data['qrUrl'])?.toString();
        if (!mounted) return;
        setState(() {
          qrCode = qrData['qrCode'];
          qrUrl = (u != null && u.isNotEmpty) ? u : null;
        });
      } else {
        final u = data['qrUrl']?.toString();
        if (!mounted) return;
        setState(() {
          qrCode = null;
          qrUrl = (u != null && u.isNotEmpty) ? u : null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        setState(() {
          isForbidden = true;
          forbiddenMessage =
              (e.response?.data is Map<String, dynamic>
                  ? (e.response?.data['message'] as String?)
                  : null) ??
              'У вас нет доступа к модулю WhatsApp. Войдите под владельцем или менеджером.';
        });
      }
    } finally {
      if (mounted) _isCheckingStatus = false;
    }
  }

  Future<void> _reconnectWhatsApp() async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
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

      // validateStatus: не бросать при 500 — показываем сообщение из ответа
      final response = await dio.post(
        '/api/whatsapp/reconnect',
        options: Options(validateStatus: (s) => s != null && s! < 600),
      );

      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса

        final data = response.data is Map
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final qrFromReconnect = data['qrCode'];
        final qrUrlFromReconnect = (data['qrUrl'] ?? '').toString();
        final success = data['success'] ?? false;
        final msg = (data['message'] ?? '').toString();

        setState(() {
          qrCode = qrFromReconnect;
          qrUrl = qrUrlFromReconnect.isNotEmpty ? qrUrlFromReconnect : null;
          isWhatsAppReady = false;
          if (msg.isNotEmpty) statusMessage = msg;
        });

        if (qrFromReconnect != null || qrUrlFromReconnect.isNotEmpty) {
          _showQRDialog(
            qrCodeOverride: qrFromReconnect,
            qrUrlOverride: qrUrlFromReconnect.isNotEmpty
                ? qrUrlFromReconnect
                : null,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Отсканируйте QR код для авторизации'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (success) {
          await _checkWhatsAppStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp переподключен'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await _checkWhatsAppStatus();
          String displayMsg;
          if (response.statusCode == 404) {
            displayMsg =
                'Маршрут не найден (404). Проверьте API_BASE_URL и что бэкенд запущен на правильном порту.';
          } else if (response.statusCode == 500 &&
              (msg.isEmpty || msg.toLowerCase().contains('internal server'))) {
            displayMsg =
                'Ошибка сервера. Проверьте логи бэкенда (pm2 logs) и настройки Green API в .env';
          } else {
            displayMsg = msg.isNotEmpty ? msg : 'Ошибка переподключения';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса

        final errMsg = e.toString().contains('GREEN_API_TOKEN')
            ? 'Токен Green API не настроен. Добавьте GREEN_API_TOKEN_INSTANCE в .env'
            : userFacingApiMessage(e, prefix: 'Ошибка переподключения');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        _checkWhatsAppStatus();
      }
    }
  }

  Future<void> _logoutWhatsApp() async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
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

      final response = await dio.post('/api/whatsapp/logout');
      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final success = data['success'] ?? true;
      final msg = (data['message'] ?? '').toString();

      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы успешно вышли из WhatsApp'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.isNotEmpty ? msg : 'Ошибка выхода'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Сбрасываем состояние
        setState(() {
          isWhatsAppReady = false;
          qrCode = null;
          statusMessage = 'Требуется авторизация';
        });

        // Обновляем статус (создаст новую сессию и покажет QR код)
        await _checkWhatsAppStatus();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог прогресса

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Ошибка выхода')),
            backgroundColor: Colors.red,
          ),
        );
        await _checkWhatsAppStatus();
      }
    }
  }

  Future<void> _refreshQr() async {
    try {
      final qrResponse = await dio.get('/api/whatsapp/qr');
      final data = qrResponse.data is Map
          ? qrResponse.data as Map<String, dynamic>
          : <String, dynamic>{};
      final url = data['qrUrl']?.toString();
      setState(() {
        qrCode = data['qrCode'];
        qrUrl = (url != null && url.isNotEmpty) ? url : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Не удалось обновить QR')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkAuthorizationStatusWithMessage() async {
    await _checkWhatsAppStatus();
    if (!mounted) return;

    final text = isWhatsAppReady
        ? 'Авторизация активна'
        : (statusMessage ?? 'Требуется авторизация');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isWhatsAppReady ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _loadTemplates() async {
    try {
      final response = await dio.get('/api/whatsapp/templates');
      setState(() {
        templates = List<Map<String, dynamic>>.from(response.data);
      });
    } catch (e) {}
  }

  Future<void> _loadCustomers() async {
    try {
      final response = await dio.get('/api/customers');
      setState(() {
        customers = List<Map<String, dynamic>>.from(response.data)
            .where(
              (c) => c['phone'] != null && c['phone'].toString().isNotEmpty,
            )
            .toList();
      });
    } catch (e) {}
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
    } catch (e) {}
  }

  Future<void> _createDefaultTemplates() async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
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
          SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendBulkMessages(String template) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
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
        .map(
          (c) => {
            'phone': c['phone'],
            'name': c['name'],
            'customerId': c['id'],
          },
        )
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
            content: Text('Отправлено: $sent, Ошибок: $failed'),
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
            content: Text(userFacingApiMessage(e, prefix: 'Ошибка отправки')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 768;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isOffline) {
      return OfflinePlaceholder(onRetry: _loadInitialData);
    }

    if (isForbidden) {
      return UnauthorizedPlaceholder(
        message:
            forbiddenMessage ??
            'У вас нет доступа к этому разделу. Войдите под владельцем или менеджером, чтобы использовать WhatsApp‑рассылку.',
        isForbidden: false,
      );
    }

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          // Заголовок и статус — адаптивно
          Padding(
            padding: EdgeInsets.all(_isMobile ? 12 : 24),
            child: _isMobile ? _buildHeaderMobile() : _buildHeaderDesktop(),
          ),

          // Табы — на мобилке скроллируемые
          TabBar(
            controller: _tabController,
            isScrollable: _isMobile,
            labelStyle: TextStyle(fontSize: _isMobile ? 12 : 14),
            tabs: const [
              Tab(icon: Icon(Icons.send), text: 'Рассылка'),
              Tab(icon: Icon(Icons.text_snippet), text: 'Шаблоны'),
              Tab(icon: Icon(Icons.history), text: 'История'),
            ],
          ),

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
      ),
    );
  }

  Widget _buildHeaderDesktop() {
    return Row(
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isWhatsAppReady ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusMessage ?? 'Загрузка...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isWhatsAppReady && (qrCode != null || qrUrl != null))
          ElevatedButton.icon(
            onPressed: () => _showQRDialog(),
            icon: const Icon(Icons.qr_code),
            label: const Text('Авторизация'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _checkAuthorizationStatusWithMessage,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Проверить статус'),
        ),
        const SizedBox(width: 8),
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
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadInitialData,
          tooltip: 'Обновить',
        ),
      ],
    );
  }

  Widget _buildHeaderMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF25D366),
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isWhatsAppReady ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusMessage ?? 'Загрузка...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInitialData,
              iconSize: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isWhatsAppReady && (qrCode != null || qrUrl != null))
              FilledButton.icon(
                onPressed: () => _showQRDialog(),
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('Авторизация'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _checkAuthorizationStatusWithMessage,
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Статус'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            if (!isWhatsAppReady)
              FilledButton.icon(
                onPressed: _reconnectWhatsApp,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Переподключить'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            if (isWhatsAppReady)
              FilledButton.icon(
                onPressed: _logoutWhatsApp,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Выйти'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSendTab() {
    final margin = _isMobile ? 8.0 : 16.0;
    final padding = _isMobile ? 12.0 : 24.0;

    final recipientsList = customers.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Нет клиентов',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: _isMobile ? 14 : 16,
                ),
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: _isMobile,
            physics: _isMobile ? const AlwaysScrollableScrollPhysics() : null,
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              final isSelected = selectedCustomers.contains(customer['id']);
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
                title: Text(customer['name'], overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  customer['phone'] ?? 'Нет телефона',
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                dense: _isMobile,
              );
            },
          );

    final recipientsCard = Card(
      margin: EdgeInsets.all(margin),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: _isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Получатели (${selectedCustomers.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedCustomers = customers
                              .map<int>((c) => c['id'] as int)
                              .toSet();
                        });
                      },
                      child: Text(_isMobile ? 'Все' : 'Выбрать все'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => selectedCustomers.clear()),
                      child: Text(_isMobile ? 'Снять' : 'Снять все'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isMobile)
            SizedBox(height: 200, child: recipientsList)
          else
            Expanded(child: recipientsList),
        ],
      ),
    );

    final templatesContent = templates.isEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.text_snippet_outlined,
                size: _isMobile ? 48 : 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text('Нет шаблонов'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _createDefaultTemplates,
                child: const Text('Создать шаблоны'),
              ),
            ],
          )
        : ListView.builder(
            shrinkWrap: _isMobile,
            physics: _isMobile ? const AlwaysScrollableScrollPhysics() : null,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final canSend = isWhatsAppReady && selectedCustomers.isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    template['name'],
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    template['content'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: _isMobile ? 12 : 14),
                  ),
                  trailing: FilledButton(
                    onPressed: canSend
                        ? () => _sendBulkMessages(template['content'])
                        : null,
                    child: Text(
                      !isWhatsAppReady
                          ? '—'
                          : selectedCustomers.isEmpty
                          ? 'Выбрать'
                          : 'Отправить',
                      style: TextStyle(fontSize: _isMobile ? 11 : 12),
                    ),
                  ),
                  dense: _isMobile,
                ),
              );
            },
          );

    final templatesCard = Card(
      margin: EdgeInsets.all(margin),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: _isMobile ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text('Шаблоны', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_isMobile && templates.isNotEmpty)
              SizedBox(height: 200, child: templatesContent)
            else if (!_isMobile)
              Expanded(child: templatesContent)
            else
              templatesContent,
          ],
        ),
      ),
    );

    if (_isMobile) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [recipientsCard, templatesCard],
        ),
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: recipientsCard),
        Expanded(flex: 1, child: templatesCard),
      ],
    );
  }

  Widget _buildTemplatesTab() {
    return WhatsAppTemplatesTab(
      dio: dio,
      templates: templates,
      onReload: _loadTemplates,
      isMobile: _isMobile,
      onCreateDefaults: _createDefaultTemplates,
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        if (historyStats != null)
          Padding(
            padding: EdgeInsets.all(_isMobile ? 8 : 16),
            child: _isMobile
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Всего',
                          historyStats!['total'].toString(),
                          Icons.send,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatCard(
                          'OK',
                          historyStats!['sent'].toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatCard(
                          'Ошибок',
                          historyStats!['failed'].toString(),
                          Icons.error,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatCard(
                          '%',
                          '${historyStats!['successRate']}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Всего отправлено',
                          historyStats!['total'].toString(),
                          Icons.send,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Успешно',
                          historyStats!['sent'].toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Ошибок',
                          historyStats!['failed'].toString(),
                          Icons.error,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Успешность',
                          '${historyStats!['successRate']}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
          ),

        const Divider(height: 1),

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
                  padding: EdgeInsets.all(_isMobile ? 8 : 16),
                  itemCount: messageHistory.length,
                  itemBuilder: (context, index) {
                    final message = messageHistory[index];
                    final isSent = message['status'] == 'sent';
                    final date = DateTime.parse(message['sentAt']);

                    return Card(
                      margin: EdgeInsets.only(bottom: _isMobile ? 8 : 12),
                      child: ListTile(
                        dense: _isMobile,
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
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
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
    final compact = _isMobile;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 20 : 32),
            SizedBox(height: compact ? 4 : 8),
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 16 : 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQRDialog({
    String? qrCodeOverride,
    String? qrUrlOverride,
  }) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      // На мобилке — авторизация по коду (GetAuthorizationCode) вместо QR
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _WhatsAppAuthCodeScreen(
            dio: dio,
            onCheckStatus: () {
              Navigator.pop(context);
              _checkWhatsAppStatus();
            },
          ),
        ),
      );
    } else {
      final qrWidget = _WhatsAppQRDialog(
        qrCode: qrCodeOverride ?? qrCode,
        qrUrl: qrUrlOverride ?? qrUrl,
        onRefresh: _refreshQr,
        onCheckStatus: () {
          Navigator.pop(context);
          _checkWhatsAppStatus();
        },
      );
      showDialog(context: context, builder: (_) => qrWidget);
    }
  }
}

/// Экран авторизации по коду для мобильных (GetAuthorizationCode вместо QR).
class _WhatsAppAuthCodeScreen extends StatefulWidget {
  final Dio dio;
  final VoidCallback onCheckStatus;

  const _WhatsAppAuthCodeScreen({
    required this.dio,
    required this.onCheckStatus,
  });

  @override
  State<_WhatsAppAuthCodeScreen> createState() =>
      _WhatsAppAuthCodeScreenState();
}

class _WhatsAppAuthCodeScreenState extends State<_WhatsAppAuthCodeScreen> {
  final _phoneController = TextEditingController();
  String? _authCode;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCode() async {
    final phone = _phoneController.text.trim().replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );
    if (phone.isEmpty) {
      setState(() {
        _error = 'Введите номер телефона';
        _authCode = null;
      });
      return;
    }
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      setState(() {
        _error = 'Номер должен содержать минимум 10 цифр';
        _authCode = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _authCode = null;
      _isLoading = true;
    });

    try {
      // Нормализация: 8XXXXXXXXXX → 7XXXXXXXXXX, 10 цифр → 7XXXXXXXXXX
      String phoneForApi = digitsOnly;
      if (digitsOnly.startsWith('8') && digitsOnly.length == 11) {
        phoneForApi = '7${digitsOnly.substring(1)}';
      } else if (digitsOnly.length == 10 && !digitsOnly.startsWith('7')) {
        phoneForApi = '7$digitsOnly';
      }

      final response = await widget.dio.post(
        '/api/whatsapp/auth-code',
        data: {'phoneNumber': phoneForApi},
      );
      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final success = data['success'] ?? false;
      final code = data['code']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success && code.isNotEmpty) {
            _authCode = code;
            _error = null;
          } else {
            _authCode = null;
            _error =
                data['message']?.toString() ??
                'Код не получен. Нажмите «Выйти» и повторите.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authCode = null;
          _error = userFacingApiMessage(e, prefix: 'Ошибка получения кода');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация WhatsApp'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onCheckStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Проверить статус'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Свяжите устройство по номеру телефона',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Откройте WhatsApp на телефоне\n'
              '2. Настройки → Связанные устройства\n'
              '3. Привязка устройства → Связать по номеру телефона\n'
              '4. Введите номер ниже и получите код',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер телефона',
                hintText: '79001234567',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _getCode(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            FilledButton.icon(
              onPressed: _isLoading ? null : _getCode,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sms),
              label: Text(_isLoading ? 'Получение кода...' : 'Получить код'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_authCode != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF25D366)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Введите этот код в WhatsApp:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _authCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Код действует ~2.5 минуты',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
}

class _WhatsAppQRDialog extends StatelessWidget {
  final String? qrCode;
  final String? qrUrl;
  final VoidCallback onRefresh;
  final VoidCallback onCheckStatus;

  /// Green API возвращает base64-изображение (data:image/png;base64,...).
  /// Альтернативно — строку для кодирования в QR (QrImageView).
  static Widget _buildQrWidget(String qrCode, double size) {
    if (qrCode.startsWith('data:image') && qrCode.contains('base64,')) {
      try {
        final base64 = qrCode.split('base64,').last;
        final bytes = base64Decode(base64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } catch (_) {
        return QrImageView(
          data: qrCode,
          version: QrVersions.auto,
          size: size,
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
        );
      }
    }
    return QrImageView(
      data: qrCode,
      version: QrVersions.auto,
      size: size,
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
    );
  }

  const _WhatsAppQRDialog({
    required this.qrCode,
    this.qrUrl,
    required this.onRefresh,
    required this.onCheckStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final qrSize = isMobile ? 280.0 : 360.0;

    Widget content = SingleChildScrollView(
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
              child: _WhatsAppQRDialog._buildQrWidget(qrCode!, qrSize),
            )
          else if (qrUrl != null && qrUrl!.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'QR код отображается по ссылке Green API',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(qrUrl!);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Открыть QR в браузере'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Container(
              height: qrSize,
              width: qrSize,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
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
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Авторизация WhatsApp'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(onPressed: onRefresh, child: const Text('Обновить QR')),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onCheckStatus();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Проверить статус'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: content),
      );
    }

    return AlertDialog(
      title: const Text('Авторизация WhatsApp'),
      content: SizedBox(width: 450, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        TextButton(onPressed: onRefresh, child: const Text('Обновить QR')),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onCheckStatus();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Проверить статус'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
