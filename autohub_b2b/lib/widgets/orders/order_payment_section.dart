import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Приём оплаты по заказу: сумма, нал или карта, остаток.
class OrderPaymentSection extends StatefulWidget {
  const OrderPaymentSection({
    super.key,
    required this.dio,
    required this.orderId,
    required this.total,
    required this.payments,
    required this.paidAmount,
    required this.dueAmount,
    this.onChanged,
  });

  final Dio dio;
  final int orderId;
  final double total;
  final List<OrderPaymentModel> payments;
  final double paidAmount;
  final double dueAmount;
  final VoidCallback? onChanged;

  @override
  State<OrderPaymentSection> createState() => _OrderPaymentSectionState();
}

class _OrderPaymentSectionState extends State<OrderPaymentSection> {
  late List<OrderPaymentModel> _payments;
  late double _paid;
  late double _due;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _payments = List.of(widget.payments);
    _paid = widget.paidAmount;
    _due = widget.dueAmount;
  }

  Future<void> _apply(Map<String, dynamic> data) async {
    final order = OrderModel.fromJson(data);
    setState(() {
      _payments = order.payments;
      _paid = order.paidAmount;
      _due = order.dueAmount;
    });
    widget.onChanged?.call();
  }

  Future<void> _takePayment() async {
    final amountController = TextEditingController(
      text: _due > 0 ? _due.toStringAsFixed(_due == _due.roundToDouble() ? 0 : 2) : '',
    );
    var method = 'cash';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Принять оплату'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MethodButton(
                      label: 'Нал',
                      selected: method == 'cash',
                      onTap: () => setLocal(() => method = 'cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MethodButton(
                      label: 'Карта',
                      selected: method == 'card',
                      onTap: () => setLocal(() => method = 'card'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Принять'),
            ),
          ],
        ),
      ),
    );
    final raw = amountController.text.trim().replaceAll(',', '.');
    amountController.dispose();
    if (accepted != true || !mounted) return;

    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      _showError('Укажите сумму оплаты');
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await widget.dio.post(
        '/api/orders/${widget.orderId}/payments',
        data: {'amount': amount, 'method': method},
      );
      if (!mounted) return;
      await _apply(response.data as Map<String, dynamic>);
    } catch (e) {
      if (mounted) _showError(userFacingApiMessage(e, prefix: 'Ошибка'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(OrderPaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить оплату?'),
        content: Text('${_money(payment.amount)} ₸'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final response = await widget.dio.delete(
        '/api/orders/${widget.orderId}/payments/${payment.id}',
      );
      if (!mounted) return;
      await _apply(response.data as Map<String, dynamic>);
    } catch (e) {
      if (mounted) _showError(userFacingApiMessage(e, prefix: 'Ошибка'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => NumberFormat('#,##0.##', 'ru_RU').format(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Оплачено ${_money(_paid)} ₸ · остаток ${_money(_due)} ₸',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        if (_payments.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._payments.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${payment.isCard ? 'Карта' : 'Нал'} · ${_money(payment.amount)} ₸',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Удалить',
                    onPressed: _busy ? null : () => _remove(payment),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy || _due <= 0 ? null : _takePayment,
            child: Text(_due <= 0 ? 'Оплачено' : 'Принять оплату'),
          ),
        ),
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppTheme.primaryColor.withOpacity(0.08) : null,
        side: BorderSide(
          color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
      ),
      child: Text(label),
    );
  }
}
