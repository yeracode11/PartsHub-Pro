import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transactions_bloc.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _userFilter = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      context.read<TransactionsBloc>().add(
            TransactionsRequested(
              from: now.subtract(const Duration(days: 30)),
              to: now,
            ),
          );
    });
  }

  @override
  void dispose() {
    _userFilter.dispose();
    super.dispose();
  }

  String? get _userIdQuery {
    final q = _userFilter.text.trim();
    return q.isEmpty ? null : q;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: BlocBuilder<TransactionsBloc, TransactionsState>(
        builder: (context, state) {
          return LoadingOverlay(
            loading: state.loading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transactions', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DateButton(
                      label: 'From',
                      value: state.from,
                      onPick: (d) => _reload(
                            context,
                            from: d,
                            to: state.to,
                            userId: _userIdQuery,
                          ),
                    ),
                    _DateButton(
                      label: 'To',
                      value: state.to,
                      onPick: (d) => _reload(
                            context,
                            from: state.from,
                            to: d,
                            userId: _userIdQuery,
                          ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _userFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by user ID',
                          isDense: true,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _reload(
                        context,
                        from: state.from,
                        to: state.to,
                        userId: _userIdQuery,
                      ),
                      child: const Text('Apply filters'),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => _reload(
                        context,
                        from: state.from,
                        to: state.to,
                        userId: _userIdQuery,
                      ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state.error != null) {
                        return InlineError(
                          message: state.error!,
                          onRetry: () => _reload(
                            context,
                            from: state.from,
                            to: state.to,
                            userId: _userIdQuery,
                          ),
                        );
                      }
                      if (state.loading && state.items.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.items.isEmpty) {
                        return const EmptyState(
                          title: 'No transactions',
                          subtitle: 'Adjust date range or filters.',
                        );
                      }
                      return _TxTable(items: state.items);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _reload(
    BuildContext context, {
    DateTime? from,
    DateTime? to,
    String? userId,
  }) {
    context.read<TransactionsBloc>().add(
          TransactionsRequested(from: from, to: to, userId: userId),
        );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(value == null ? label : '$label: ${df.format(value!)}'),
      onPressed: () async {
        final initial = value ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}

class _TxTable extends StatelessWidget {
  const _TxTable({required this.items});

  final List<TransactionEntity> items;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_Hm();
    final money = NumberFormat.currency(symbol: r'$');
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
            ],
            rows: [
              for (final t in items)
                DataRow(
                  cells: [
                    DataCell(SelectableText(t.id)),
                    DataCell(Text(t.userId ?? '—')),
                    DataCell(Text(t.amount != null ? money.format(t.amount!) : '—')),
                    DataCell(Text(t.status ?? '—')),
                    DataCell(Text(t.createdAt != null ? df.format(t.createdAt!) : '—')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
