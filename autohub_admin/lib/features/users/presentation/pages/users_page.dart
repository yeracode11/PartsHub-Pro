import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../data/models/user_entity.dart';
import '../bloc/users_bloc.dart';
import '../widgets/user_form_dialog.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersBloc>().add(const UsersLoadRequested(page: 1, search: ''));
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: BlocConsumer<UsersBloc, UsersState>(
        listener: (context, state) {
          final msg = state.mutationError;
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
        builder: (context, state) {
          final page = state.page;
          return LoadingOverlay(
            loading: state.listLoading || state.mutating,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Users', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () async {
                        final body = await showDialog<Map<String, dynamic>?>(
                          context: context,
                          builder: (_) => const UserFormDialog(),
                        );
                        if (!context.mounted || body == null) return;
                        context.read<UsersBloc>().add(UserSaved(id: null, body: body));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create user'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          labelText: 'Search by email or name',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => context.read<UsersBloc>().add(
                                  UsersSearchChanged(_search.text),
                                ),
                          ),
                        ),
                        onSubmitted: (_) => context.read<UsersBloc>().add(
                              UsersSearchChanged(_search.text),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state.listError != null) {
                        return InlineError(
                          message: state.listError!,
                          onRetry: () => context.read<UsersBloc>().add(
                                UsersLoadRequested(page: state.currentPage, search: state.search),
                              ),
                        );
                      }
                      if (page == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (page.items.isEmpty) {
                        return const EmptyState(
                          title: 'No users',
                          subtitle: 'Adjust search or create a user.',
                        );
                      }
                      return _UsersTable(
                        items: page.items,
                        total: page.total,
                        pageIndex: state.currentPage,
                        pageSize: AppConfig.defaultPageSize,
                        onPrev: state.currentPage > 1
                            ? () => context.read<UsersBloc>().add(
                                  UsersLoadRequested(
                                    page: state.currentPage - 1,
                                    search: state.search,
                                  ),
                                )
                            : null,
                        onNext: state.currentPage * AppConfig.defaultPageSize < page.total
                            ? () => context.read<UsersBloc>().add(
                                  UsersLoadRequested(
                                    page: state.currentPage + 1,
                                    search: state.search,
                                  ),
                                )
                            : null,
                        onEdit: (user) async {
                          final body = await showDialog<Map<String, dynamic>?>(
                            context: context,
                            builder: (_) => UserFormDialog(existing: user),
                          );
                          if (!context.mounted || body == null) return;
                          context.read<UsersBloc>().add(UserSaved(id: user.id, body: body));
                        },
                        onDelete: (user) async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete user'),
                              content: Text('Delete ${user.email}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {
                            context.read<UsersBloc>().add(UserDeleted(user.id));
                          }
                        },
                      );
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

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
    required this.onEdit,
    required this.onDelete,
  });

  final List<UserEntity> items;
  final int total;
  final int pageIndex;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<UserEntity> onEdit;
  final ValueChanged<UserEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Active')),
                    DataColumn(label: Text('Organization')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final u in items)
                      DataRow(
                        cells: [
                          DataCell(Text(u.email)),
                          DataCell(Text(u.name)),
                          DataCell(Text(u.role)),
                          DataCell(Text(u.isActive ? 'Yes' : 'No')),
                          DataCell(Text(u.organizationId ?? '—')),
                          DataCell(Text(u.createdAt != null ? df.format(u.createdAt!) : '—')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => onEdit(u),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => onDelete(u),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Total: $total · Page $pageIndex'),
            const Spacer(),
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
    );
  }
}
