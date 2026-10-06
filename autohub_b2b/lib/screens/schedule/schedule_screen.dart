import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/screens/sales/order_detail_screen.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _dio = ApiClient().dio;
  DateTime _day = DateTime.now();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;

  bool get _canEdit {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated &&
        (state.user.role == UserRole.owner || state.user.role == UserRole.manager);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _dayStart => DateTime(_day.year, _day.month, _day.day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _dayStart.toUtc().toIso8601String();
      final to = _dayStart.add(const Duration(days: 1)).toUtc().toIso8601String();
      final results = await Future.wait([
        _dio.get('/api/schedule/posts'),
        _dio.get('/api/schedule/appointments', queryParameters: {'from': from, 'to': to}),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = (results[0].data as List).cast<Map<String, dynamic>>();
        _appointments = (results[1].data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingApiMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AppointmentDialog(day: _dayStart, posts: _posts),
    );
    if (saved == true) _load();
  }

  Future<void> _open(Map<String, dynamic> appointment) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AppointmentSheet(
        appointment: appointment,
        canEdit: _canEdit,
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _managePosts() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PostsDialog(posts: _posts),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd.MM.yyyy').format(_dayStart);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _day = _dayStart.subtract(const Duration(days: 1)));
                  _load();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _day = _dayStart.add(const Duration(days: 1)));
                  _load();
                },
                icon: const Icon(Icons.chevron_right),
              ),
              if (_canEdit)
                TextButton(onPressed: _managePosts, child: const Text('Посты')),
              if (_canEdit)
                IconButton(
                  tooltip: 'Новая запись',
                  onPressed: _posts.isEmpty ? null : _add,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _load, child: const Text('Повторить')),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: _posts.map(_buildPost).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildPost(Map<String, dynamic> post) {
    final items = _appointments
        .where((item) => item['postId'] == post['id'] && item['status'] != 'cancelled')
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post['name']?.toString() ?? 'Пост',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Свободно',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _open(item),
                  title: Text(_title(item)),
                  subtitle: Text(_subtitle(item)),
                  trailing: Text(_time(item)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _title(Map<String, dynamic> item) {
    final customer = item['customer'] as Map<String, dynamic>?;
    return customer?['name']?.toString() ?? 'Без клиента';
  }

  String _subtitle(Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as Map<String, dynamic>?;
    final master = item['master'] as Map<String, dynamic>?;
    final car = vehicle == null
        ? null
        : '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['plateNumber'] ?? ''}'
            .trim();
    return [
      if (car != null && car.isNotEmpty) car,
      if (master?['name'] != null) master!['name'].toString(),
      _statusLabel(item['status']?.toString()),
    ].join(' · ');
  }

  String _time(Map<String, dynamic> item) {
    final start = DateTime.tryParse(item['startsAt']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(item['endsAt']?.toString() ?? '')?.toLocal();
    if (start == null || end == null) return '';
    final format = DateFormat('HH:mm');
    return '${format.format(start)}–${format.format(end)}';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'arrived':
        return 'Приехал';
      case 'in_progress':
        return 'В работе';
      case 'done':
        return 'Готово';
      case 'cancelled':
        return 'Отменена';
      default:
        return 'Записан';
    }
  }
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({required this.day, required this.posts});

  final DateTime day;
  final List<Map<String, dynamic>> posts;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _dio = ApiClient().dio;
  final _notes = TextEditingController();
  List<CustomerModel> _customers = [];
  List<Map<String, dynamic>> _masters = [];
  int? _postId;
  int? _customerId;
  int? _vehicleId;
  String? _masterId;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _postId = widget.posts.isEmpty ? null : widget.posts.first['id'] as int?;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _dio.get('/api/customers'),
        _dio.get('/api/schedule/masters'),
      ]);
      if (!mounted) return;
      setState(() {
        _customers = (results[0].data as List)
            .map((item) => CustomerModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _masters = (results[1].data as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  CustomerModel? get _customer {
    for (final customer in _customers) {
      if (customer.id == _customerId) return customer;
    }
    return null;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_postId == null) return;
    final starts = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _time.hour,
      _time.minute,
    );
    setState(() => _saving = true);
    try {
      await _dio.post('/api/schedule/appointments', data: {
        'postId': _postId,
        'customerId': _customerId,
        'vehicleId': _vehicleId,
        'masterId': _masterId,
        'startsAt': starts.toUtc().toIso8601String(),
        'durationMinutes': _duration,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _customer?.vehicles ?? [];
    return AlertDialog(
      title: const Text('Новая запись'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _postId,
                decoration: const InputDecoration(
                  labelText: 'Пост',
                  border: OutlineInputBorder(),
                ),
                items: widget.posts
                    .map(
                      (post) => DropdownMenuItem(
                        value: post['id'] as int,
                        child: Text(post['name']?.toString() ?? 'Пост'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _postId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(_time.format(context)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _duration,
                      decoration: const InputDecoration(
                        labelText: 'Минуты',
                        border: OutlineInputBorder(),
                      ),
                      items: const [30, 60, 90, 120, 180]
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _duration = value ?? 60),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _customerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Клиент',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Без клиента')),
                  ..._customers.where((customer) => customer.id != null).map(
                        (customer) => DropdownMenuItem(
                          value: customer.id,
                          child: Text(customer.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() {
                  _customerId = value;
                  _vehicleId = null;
                }),
              ),
              if (vehicles.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Автомобиль',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Без авто')),
                    ...vehicles.map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(
                          '${vehicle.brand} ${vehicle.model} · ${vehicle.plateNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _vehicleId = value),
                ),
              ],
              if (_masters.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _masterId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Мастер',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Не назначен')),
                    ..._masters.map(
                      (master) => DropdownMenuItem(
                        value: master['id']?.toString(),
                        child: Text(master['name']?.toString() ?? 'Мастер'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _masterId = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Записать'),
        ),
      ],
    );
  }
}

class _AppointmentSheet extends StatefulWidget {
  const _AppointmentSheet({required this.appointment, required this.canEdit});

  final Map<String, dynamic> appointment;
  final bool canEdit;

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  final _dio = ApiClient().dio;
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.appointment['status']?.toString() ?? 'scheduled';
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _dio.patch('/api/schedule/appointments/${widget.appointment['id']}', data: {
        'status': status,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    }
  }

  Future<void> _createOrder() async {
    setState(() => _busy = true);
    try {
      await _dio.post('/api/schedule/appointments/${widget.appointment['id']}/order');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  Future<void> _openOrder() async {
    final orderId = widget.appointment['orderId'];
    if (orderId == null) return;
    final response = await _dio.get('/api/orders/$orderId');
    if (!mounted) return;
    final order = OrderModel.fromJson(response.data as Map<String, dynamic>);
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order, dio: _dio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.appointment['orderId'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.appointment['customer']?['name']?.toString() ?? 'Запись',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (widget.canEdit)
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Статус',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'scheduled', child: Text('Записан')),
                DropdownMenuItem(value: 'arrived', child: Text('Приехал')),
                DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                DropdownMenuItem(value: 'done', child: Text('Готово')),
                DropdownMenuItem(value: 'cancelled', child: Text('Отменена')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) _setStatus(value);
                    },
            ),
          const SizedBox(height: 12),
          if (widget.canEdit && orderId == null && _status != 'cancelled')
            FilledButton(
              onPressed: _busy ? null : _createOrder,
              child: const Text('Создать заказ-наряд'),
            ),
          if (orderId != null)
            OutlinedButton(
              onPressed: _openOrder,
              child: const Text('Открыть заказ-наряд'),
            ),
        ],
      ),
    );
  }
}

class _PostsDialog extends StatefulWidget {
  const _PostsDialog({required this.posts});

  final List<Map<String, dynamic>> posts;

  @override
  State<_PostsDialog> createState() => _PostsDialogState();
}

class _PostsDialogState extends State<_PostsDialog> {
  final _dio = ApiClient().dio;
  final _name = TextEditingController();
  late List<Map<String, dynamic>> _posts;

  @override
  void initState() {
    super.initState();
    _posts = List.of(widget.posts);
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    try {
      final response = await _dio.post('/api/schedule/posts', data: {'name': name});
      setState(() {
        _posts.add(response.data as Map<String, dynamic>);
        _name.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Посты'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._posts.map(
              (post) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(post['name']?.toString() ?? ''),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Новый пост',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(onPressed: _add, icon: const Icon(Icons.add)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
