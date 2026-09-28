import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/models/whatsapp_connection_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/meta_whatsapp_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/screens/whatsapp/meta_whatsapp_connect_screen.dart';

enum _ScreenState { loading, ready, forbidden, error }

/// WhatsApp через Meta WhatsApp Cloud API.
///
/// Читает/создаёт подключение через существующий backend
/// `GET/POST /api/whatsapp/connections` (tenant — из JWT, без Green API).
class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  late final MetaWhatsAppService _service;
  _ScreenState _state = _ScreenState.loading;
  WhatsAppConnectionModel? _connection;
  String? _errorMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _service = MetaWhatsAppService(ApiClient());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _ScreenState.loading;
      _isOffline = false;
    });

    try {
      final connections = await _service.getConnections();
      final active = connections.where((c) => c.isActive).toList();
      final current = active.isNotEmpty ? active.first : null;

      if (!mounted) return;
      setState(() {
        _connection = current;
        _state = _ScreenState.ready;
      });
    } catch (e) {
      if (!mounted) return;

      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        setState(() {
          _state = _ScreenState.forbidden;
          _errorMessage = extractApiErrorMessage(e.response?.data) ??
              'У вас нет доступа к модулю WhatsApp. Войдите под владельцем или менеджером.';
        });
      } else if (isNetworkError(e)) {
        setState(() {
          _isOffline = true;
          _state = _ScreenState.error;
        });
      } else {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage =
              userFacingApiMessage(e, prefix: 'Не удалось загрузить статус WhatsApp');
        });
      }
    }
  }

  Future<void> _openConnectForm() async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MetaWhatsAppConnectScreen()),
    );

    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp подключен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _ScreenState.loading:
        return const Center(child: CircularProgressIndicator());

      case _ScreenState.forbidden:
        return UnauthorizedPlaceholder(message: _errorMessage, isForbidden: true);

      case _ScreenState.error:
        if (_isOffline) {
          return OfflinePlaceholder(onRetry: _load);
        }
        return _buildErrorState();

      case _ScreenState.ready:
        return _buildReadyState();
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Не удалось загрузить статус WhatsApp',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isOwner = context.select<AuthBloc, bool>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated && state.user.role == UserRole.owner;
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Meta WhatsApp Cloud API',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _load,
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_connection != null)
                  ..._buildConnectedBody(_connection!)
                else
                  ..._buildNotConnectedBody(isOwner),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConnectedBody(WhatsAppConnectionModel connection) {
    return [
      const _StatusPill(label: 'Подключен', color: Color(0xFF16A34A)),
      const SizedBox(height: 20),
      _infoRow('Business number', connection.phoneNumber ?? '—'),
      const SizedBox(height: 12),
      _infoRow('Phone Number ID', connection.phoneNumberId),
      const SizedBox(height: 12),
      _infoRow('WABA ID', connection.wabaId ?? '—'),
      if ((connection.displayName ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        _infoRow('Display name', connection.displayName!),
      ],
    ];
  }

  List<Widget> _buildNotConnectedBody(bool isOwner) {
    return [
      const _StatusPill(label: 'Не подключен', color: Color(0xFFF59E0B)),
      const SizedBox(height: 16),
      Text(
        'Подключите WhatsApp Business для получения сообщений клиентов '
        'и автоматических ответов.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
      ),
      if (isOwner) ...[
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _openConnectForm,
          icon: const Icon(Icons.link),
          label: const Text('Подключить WhatsApp'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    ];
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
