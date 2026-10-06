import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/screens/sales/order_detail_screen.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/offline_queue.dart';
import 'package:autohub_b2b/services/service_locator.dart';

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
        (state.user.role == UserRole.owner ||
            state.user.role == UserRole.manager ||
            state.user.role == UserRole.sto);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _dayStart => DateTime(_day.year, _day.month, _day.day);

  String get _dayKey =>
      'appointments-${_dayStart.year}-${_dayStart.month}-${_dayStart.day}';

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    if (!OfflineQueue().isOnline) {
      final posts = await OfflineQueue().readList('posts');
      final appointments = await OfflineQueue().readList(_dayKey);
      final merged = await _withPending(appointments ?? []);
      if (!mounted) return;
      if (posts == null && appointments == null && merged.isEmpty) {
        setState(() {
          _error = 'Нет подключения и нет сохранённой копии';
          _loading = false;
        });
        return;
      }
      setState(() {
        _posts = posts ?? [];
        _appointments = merged;
        _loading = false;
      });
      return;
    }
    try {
      final from = _dayStart.toUtc().toIso8601String();
      final to = _dayStart.add(const Duration(days: 1)).toUtc().toIso8601String();
      final results = await Future.wait([
        _dio.get('/api/schedule/posts'),
        _dio.get('/api/schedule/appointments', queryParameters: {'from': from, 'to': to}),
      ]);
      if (!mounted) return;
      final posts = (results[0].data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final appointments = (results[1].data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      await OfflineQueue().writeList('posts', posts);
      await OfflineQueue().writeList(_dayKey, appointments);
      final merged = await _withPending(appointments);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _appointments = merged;
        _loading = false;
      });
    } catch (e) {
      final posts = await OfflineQueue().readList('posts');
      final appointments = await OfflineQueue().readList(_dayKey);
      if (!mounted) return;
      if (posts == null && appointments == null) {
        setState(() {
          _error = userFacingApiMessage(e);
          _loading = false;
        });
        return;
      }
      final merged = await _withPending(appointments ?? []);
      if (!mounted) return;
      setState(() {
        _posts = posts ?? [];
        _appointments = merged;
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _withPending(
    List<Map<String, dynamic>> appointments,
  ) async {
    final merged = List<Map<String, dynamic>>.of(appointments);
    for (final snapshot in await OfflineQueue().snapshots('appointment')) {
      final starts = DateTime.tryParse(snapshot['startsAt']?.toString() ?? '')?.toLocal();
      if (starts == null) continue;
      final sameDay = starts.year == _dayStart.year &&
          starts.month == _dayStart.month &&
          starts.day == _dayStart.day;
      if (!sameDay) continue;
      final index = merged.indexWhere((item) => item['id'].toString() == snapshot['id'].toString());
      if (index >= 0) {
        merged[index] = snapshot;
      } else {
        merged.add(snapshot);
      }
    }
    return merged;
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

  int? _movingId;

  static const _columns = <(String, String, String?)>[
    ('scheduled', 'Записан', 'Приехал'),
    ('arrived', 'Приехал', 'В работу'),
    ('in_progress', 'В работе', 'Готово'),
    ('done', 'Готово', null),
  ];

  String get _dayLabel {
    const days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return '${days[_dayStart.weekday - 1]}, ${DateFormat('dd.MM').format(_dayStart)}';
  }

  Future<void> _move(Map<String, dynamic> item, String status) async {
    final id = item['id'];
    setState(() => _movingId = id is int ? id : int.tryParse('$id'));
    try {
      final result = await OfflineQueue().send(
        method: 'PATCH',
        path: '/api/schedule/appointments/$id',
        body: {'status': status},
        entity: 'appointment',
        localId: '$id',
        snapshot: {...item, 'status': status},
      );
      if (!mounted) return;
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(offlineSavedMessage)),
        );
      }
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _movingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _dayLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                  : _buildBoard(),
        ),
      ],
    );
  }

  Color _stageColor(String status) {
    switch (status) {
      case 'arrived':
        return AppTheme.accentColor;
      case 'in_progress':
        return AppTheme.textPrimary;
      case 'done':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildBoard() {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _columns.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _buildColumn(_columns[i], fill: true)),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (var i = 0; i < _columns.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _buildColumn(_columns[i], fill: false),
        ],
      ],
    );
  }

  Widget _buildColumn((String, String, String?) column, {required bool fill}) {
    final status = column.$1;
    final title = column.$2;
    final nextLabel = column.$3;
    final color = _stageColor(status);
    final nextStatus = switch (status) {
      'scheduled' => 'arrived',
      'arrived' => 'in_progress',
      'in_progress' => 'done',
      _ => null,
    };
    final items = _appointments
        .where((item) => (item['status']?.toString() ?? 'scheduled') == status)
        .toList();
    final cards = items.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Нет записей',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildCard(
                  items[i],
                  color: color,
                  nextStatus: nextStatus,
                  nextLabel: nextLabel,
                ),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (fill) Expanded(child: SingleChildScrollView(child: cards)) else cards,
      ],
    );
  }

  Widget _buildCard(
    Map<String, dynamic> item, {
    required Color color,
    required String? nextStatus,
    required String? nextLabel,
  }) {
    final id = item['id'];
    final itemId = id is int ? id : int.tryParse('$id');
    final moving = _movingId != null && _movingId == itemId;
    final nextColor = nextStatus == null ? color : _stageColor(nextStatus);
    final time = _time(item);
    return Material(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      Text(
                        _title(item),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                      if (_subtitle(item).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(item),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (_canEdit && nextStatus != null && nextLabel != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: moving ? null : () => _move(item, nextStatus),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: nextColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(moving ? 'Сохранение' : nextLabel),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(Map<String, dynamic> item) {
    final customer = item['customer'] as Map<String, dynamic>?;
    return customer?['name']?.toString() ?? 'Без клиента';
  }

  String _subtitle(Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as Map<String, dynamic>?;
    final post = item['post'] as Map<String, dynamic>?;
    final car = vehicle == null
        ? null
        : '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['plateNumber'] ?? ''}'
            .trim();
    return [
      if (car != null && car.isNotEmpty) car,
      if (post?['name'] != null) post!['name'].toString(),
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  String _time(Map<String, dynamic> item) {
    final start = DateTime.tryParse(item['startsAt']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(item['endsAt']?.toString() ?? '')?.toLocal();
    if (start == null || end == null) return '';
    final format = DateFormat('HH:mm');
    return '${format.format(start)}–${format.format(end)}';
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
      final customers = (results[0].data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final masters = (results[1].data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      await OfflineQueue().writeList('customers', customers);
      await OfflineQueue().writeList('scheduleMasters', masters);
      setState(() {
        _customers = customers.map(CustomerModel.fromJson).toList();
        _masters = masters;
      });
    } catch (_) {
      final cachedCustomers = await OfflineQueue().readList('customers');
      final cachedMasters = await OfflineQueue().readList('scheduleMasters');
      if (!mounted) return;
      final customers = <CustomerModel>[];
      for (final json in cachedCustomers ?? []) {
        try {
          customers.add(CustomerModel.fromJson(json));
        } catch (_) {}
      }
      if (customers.isEmpty && ServiceLocator().isInitialized) {
        try {
          customers.addAll(await ServiceLocator().customersRepository.getCustomers());
        } catch (_) {}
      }
      setState(() {
        _customers = customers;
        _masters = cachedMasters ?? [];
      });
    }
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
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final ends = starts.add(Duration(minutes: _duration));
    final localId = OfflineQueue.newLocalIntId();
    Map<String, dynamic>? post;
    for (final item in widget.posts) {
      if (item['id'] == _postId) post = item;
    }
    final customer = _customer;
    VehicleModel? vehicle;
    if (customer != null && _vehicleId != null) {
      for (final item in customer.vehicles) {
        if (item.id == _vehicleId) vehicle = item;
      }
    }
    try {
      final result = await OfflineQueue().send(
        method: 'POST',
        path: '/api/schedule/appointments',
        body: {
          'postId': _postId,
          'customerId': _customerId,
          'vehicleId': _vehicleId,
          'masterId': _masterId,
          'startsAt': starts.toUtc().toIso8601String(),
          'durationMinutes': _duration,
          'notes': notes,
        },
        entity: 'appointment',
        localId: '$localId',
        snapshot: {
          'id': localId,
          'status': 'scheduled',
          'startsAt': starts.toIso8601String(),
          'endsAt': ends.toIso8601String(),
          'notes': notes,
          'post': post == null ? null : {'id': post['id'], 'name': post['name']},
          'customer': customer == null ? null : {'id': customer.id, 'name': customer.name},
          'vehicle': vehicle == null
              ? null
              : {
                  'brand': vehicle.brand,
                  'model': vehicle.model,
                  'plateNumber': vehicle.plateNumber,
                },
        },
      );
      if (!mounted) return;
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(offlineSavedMessage)),
        );
      }
      Navigator.pop(context, true);
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
                    labelText: 'СТО',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Не назначен')),
                    ..._masters.map(
                      (master) => DropdownMenuItem(
                        value: master['id']?.toString(),
                        child: Text(master['name']?.toString() ?? 'СТО'),
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
      final result = await OfflineQueue().send(
        method: 'PATCH',
        path: '/api/schedule/appointments/${widget.appointment['id']}',
        body: {'status': status},
        entity: 'appointment',
        localId: '${widget.appointment['id']}',
        snapshot: {...widget.appointment, 'status': status},
      );
      if (!mounted) return;
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(offlineSavedMessage)),
        );
      }
      Navigator.pop(context, true);
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
      final result = await OfflineQueue().send(
        method: 'POST',
        path: '/api/schedule/appointments/${widget.appointment['id']}/order',
        entity: 'appointmentOrder',
        localId: '${widget.appointment['id']}',
        snapshot: {'appointmentId': widget.appointment['id']},
      );
      if (!mounted) return;
      if (result.queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(offlineSavedMessage)),
        );
      }
      Navigator.pop(context, true);
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

  Future<void> _rename(Map<String, dynamic> post) async {
    final controller = TextEditingController(text: post['name']?.toString() ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Имя поста'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final response = await _dio.patch(
        '/api/schedule/posts/${post['id']}',
        data: {'name': name},
      );
      if (!mounted) return;
      setState(() {
        final index = _posts.indexWhere((item) => item['id'] == post['id']);
        if (index >= 0) {
          _posts[index] = Map<String, dynamic>.from(response.data as Map);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    }
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
                trailing: IconButton(
                  tooltip: 'Изменить имя',
                  onPressed: () => _rename(post),
                  icon: const Icon(Icons.edit_outlined),
                ),
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
