import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/services/services_bloc.dart';
import '../../blocs/services/services_event.dart';
import '../../blocs/services/services_state.dart';
import '../../core/design/app_spacing.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/service_card.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ServicesBloc>().add(ServicesLoadRequested());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0,
              ),
              child: const PageHeader(
                title: 'Сервис',
                subtitle: 'Запись на ТО и ремонт',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: AppSearchField(
                controller: _search,
                hint: 'Название сервиса',
                onChanged: (q) => context.read<ServicesBloc>().add(
                      ServicesSearchRequested(q),
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: BlocBuilder<ServicesBloc, ServicesState>(
                builder: (context, state) {
                  if (state is ServicesLoading) {
                    return const LoadingView();
                  }
                  if (state is ServicesError) {
                    return ErrorView(
                      message: state.message,
                      onRetry: () => context
                          .read<ServicesBloc>()
                          .add(ServicesLoadRequested()),
                    );
                  }
                  if (state is ServicesLoaded) {
                    if (state.services.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.build_outlined,
                        title: 'Сервисы не найдены',
                        subtitle: 'Измените поисковый запрос',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        0,
                        AppSpacing.xxl,
                        AppSpacing.xxl,
                      ),
                      itemCount: state.services.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) {
                        final service = state.services[index];
                        return ServiceCard(
                          service: service,
                          onTap: () => context.push(
                            '/service/${service.id}',
                            extra: service,
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
