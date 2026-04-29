import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../data/models/subscription_entity.dart';
import '../bloc/subscriptions_bloc.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionsBloc>().add(const SubscriptionsRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: BlocConsumer<SubscriptionsBloc, SubscriptionsState>(
        listener: (context, state) {
          final m = state.mutationError;
          if (m != null && m.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
          }
        },
        builder: (context, state) {
          return LoadingOverlay(
            loading: state.loading || state.mutating,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Subscriptions', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () =>
                          context.read<SubscriptionsBloc>().add(const SubscriptionsRequested()),
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
                          onRetry: () =>
                              context.read<SubscriptionsBloc>().add(const SubscriptionsRequested()),
                        );
                      }
                      if (state.loading && state.items.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.items.isEmpty) {
                        return const EmptyState(
                          title: 'No subscriptions',
                          subtitle: 'When subscriptions exist, you can manage them here.',
                        );
                      }
                      return _SubscriptionsTable(items: state.items);
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
}

class _SubscriptionsTable extends StatelessWidget {
  const _SubscriptionsTable({required this.items});

  final List<SubscriptionEntity> items;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('User ID')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Active')),
              DataColumn(label: Text('Expires')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final s in items)
                DataRow(
                  cells: [
                    DataCell(SelectableText(s.userId)),
                    DataCell(Text(s.plan ?? '—')),
                    DataCell(Text(s.isActive ? 'Yes' : 'No')),
                    DataCell(Text(s.expiresAt != null ? df.format(s.expiresAt!) : '—')),
                    DataCell(
                      IconButton(
                        tooltip: 'Manage',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async => _openEditor(context, s),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, SubscriptionEntity s) async {
    final df = DateFormat.yMMMd();
    final planController = TextEditingController(text: s.plan ?? '');
    DateTime? expires = s.expiresAt;
    var active = s.isActive;

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('Subscription'),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Subscription ${s.id}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      TextField(
                        controller: planController,
                        decoration: const InputDecoration(labelText: 'Plan'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Active'),
                        value: active,
                        onChanged: (v) => setLocal(() => active = v),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(expires == null ? 'Expiration (optional)' : df.format(expires!)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: expires ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setLocal(() => expires = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true || !context.mounted) return;

      final patch = s.toPatchBody(
        plan: planController.text.trim().isEmpty ? null : planController.text.trim(),
        isActive: active,
        expiresAt: expires,
      );

      context.read<SubscriptionsBloc>().add(
            SubscriptionPatchSubmitted(id: s.id, body: patch),
          );
    } finally {
      planController.dispose();
    }
  }
}
