import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Зарплата и выполненные работы за текущий месяц.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _masters = [];
  bool _loading = true;
  String? _error;

  bool get _isWorker {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated && state.user.role == UserRole.worker;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final to = DateTime(now.year, now.month + 1, 1).toUtc().toIso8601String();
    try {
      final response = await _dio.get(
        '/api/payroll',
        queryParameters: {'from': from, 'to': to},
      );
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _masters = (data['masters'] as List? ?? []).cast<Map<String, dynamic>>();
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

  Future<void> _toggle(Map<String, dynamic> line, bool done) async {
    try {
      await _dio.patch('/api/payroll/works/${line['workId']}', data: {'done': done});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  String _money(num value) => NumberFormat('#,##0.##', 'ru_RU').format(value);

  String _monthLabel(DateTime date) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _rateLabel(Map<String, dynamic> master) {
    final rate = master['payRate'];
    if (master['payType'] == 'hourly') {
      return '${_money(rate is num ? rate : 0)} ₸/час';
    }
    return '${_money(rate is num ? rate : 0)}% от работы';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_masters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'За этот месяц выполненных работ нет',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _monthLabel(DateTime.now()),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._masters.map(_masterCard),
        ],
      ),
    );
  }

  Widget _lineTile(Map<String, dynamic> line, bool done) {
    final amount = line['amount'];
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: done,
      title: Text(line['name']?.toString() ?? ''),
      subtitle: Text(
        '${line['orderNumber'] ?? ''} · ${_money(amount is num ? amount : 0)} ₸',
      ),
      onChanged: (value) => _toggle(line, value ?? false),
    );
  }

  Widget _masterCard(Map<String, dynamic> master) {
    final open = (master['open'] as List? ?? []).cast<Map<String, dynamic>>();
    final lines = (master['lines'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = master['total'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isWorker ? 'К выплате' : (master['name']?.toString() ?? 'Мастер'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${_money(total is num ? total : 0)} ₸ · ${_rateLabel(master)}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ...open.map((line) => _lineTile(line, false)),
            ...lines.map((line) => _lineTile(line, true)),
          ],
        ),
      ),
    );
  }
}
