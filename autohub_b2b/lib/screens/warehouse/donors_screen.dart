import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/donor_model.dart';
import 'package:autohub_b2b/screens/warehouse/donor_detail_screen.dart';
import 'package:autohub_b2b/screens/warehouse/donor_form_screen.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/donor_service.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';

final _money = NumberFormat.currency(
  locale: 'ru_RU',
  symbol: '₸',
  decimalDigits: 0,
);

String formatMoney(double value) => _money.format(value);

/// Покупать доноров и видеть деньги могут владелец и менеджер.
bool canManageDonors(BuildContext context) => canSeeFinance(context);

/// Сколько вложений в машину уже вернулось.
class DonorPaybackBar extends StatelessWidget {
  final DonorEconomics economics;

  const DonorPaybackBar({super.key, required this.economics});

  @override
  Widget build(BuildContext context) {
    final percent = economics.paybackPercent;
    final value = percent == null ? 1.0 : (percent / 100).clamp(0.0, 1.0);
    final color = economics.isPaidBack
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;

    return Semantics(
      label: 'Окупаемость ${percent?.toStringAsFixed(0) ?? '—'} процентов',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          color: color,
          backgroundColor: AppTheme.borderColor,
        ),
      ),
    );
  }
}

/// Группы для фильтра списка: что в работе, что продаётся, что закрыто.
enum DonorGroup {
  active('В работе', {
    DonorStatus.purchased,
    DonorStatus.waitingForDismantling,
    DonorStatus.dismantling,
    DonorStatus.partiallyDismantled,
  }),
  dismantled('Разобраны', {DonorStatus.fullyDismantled}),
  archived('Архив', {DonorStatus.archived});

  const DonorGroup(this.label, this.statuses);

  final String label;
  final Set<DonorStatus> statuses;
}

class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key});

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen> {
  final DonorService _service = DonorService();
  List<DonorModel> _donors = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isForbidden = false;
  DonorGroup _group = DonorGroup.active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _isForbidden = false;
    });
    try {
      final donors = await _service.getDonors();
      if (!mounted) return;
      setState(() {
        _donors = donors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final status = e is DioException ? e.response?.statusCode : null;
      setState(() {
        _isLoading = false;
        _isForbidden = status == 401 || status == 403;
        _isOffline = !_isForbidden && isNetworkError(e);
      });
      if (!_isForbidden && !_isOffline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
      }
    }
  }

  Future<void> _createDonor() async {
    if (!await ensureAuthenticated(context)) return;
    if (!mounted) return;
    final created = await Navigator.of(context).push<DonorModel>(
      MaterialPageRoute(builder: (_) => const DonorFormScreen()),
    );
    if (created == null || !mounted) return;
    await _openDonor(created);
  }

  Future<void> _openDonor(DonorModel donor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DonorDetailScreen(donorId: donor.id)),
    );
    if (mounted) _load();
  }

  List<DonorModel> _donorsIn(DonorGroup group) =>
      _donors.where((d) => group.statuses.contains(d.status)).toList();

  @override
  Widget build(BuildContext context) {
    if (_isForbidden) {
      return const Scaffold(
        body: UnauthorizedPlaceholder(
          message: 'Учёт доноров доступен владельцу, менеджеру и кладовщику.',
          isForbidden: true,
        ),
      );
    }

    final canManage = canManageDonors(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Доноры'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _createDonor,
              icon: const Icon(Icons.add),
              label: const Text('Купить донора'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_isOffline) return OfflinePlaceholder(onRetry: _load);

    final donors = _donorsIn(_group);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummary(),
                  SegmentedButton<DonorGroup>(
                    showSelectedIcon: false,
                    segments: [
                      for (final group in DonorGroup.values)
                        ButtonSegment(
                          value: group,
                          label: Text(
                            '${group.label} · ${_donorsIn(group).length}',
                          ),
                        ),
                    ],
                    selected: {_group},
                    onSelectionChanged: (s) => setState(() => _group = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (donors.isEmpty)
                    _buildEmpty()
                  else
                    for (final donor in donors) ...[
                      _DonorCard(
                        donor: donor,
                        photoUrl: donor.photos.isEmpty
                            ? null
                            : _service.photoUrl(donor.photos.first),
                        onTap: () => _openDonor(donor),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Итог по машинам в работе: сколько денег заморожено в донорах.
  Widget _buildSummary() {
    final active = _donors
        .where((d) => !d.isArchived && d.economics != null)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    double sum(double Function(DonorEconomics e) pick) =>
        active.fold(0, (acc, d) => acc + pick(d.economics!));
    final invested = sum((e) => e.totalCost);
    final income = sum((e) => e.income);
    final stock = sum((e) => e.stockValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 32,
        runSpacing: 16,
        children: [
          _SummaryFigure(label: 'Вложено', value: formatMoney(invested)),
          _SummaryFigure(label: 'Вернулось', value: formatMoney(income)),
          _SummaryFigure(
            label: 'Не вернулось',
            value: formatMoney((invested - income).clamp(0, double.infinity)),
          ),
          _SummaryFigure(label: 'На складе', value: formatMoney(stock)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final text = switch (_group) {
      DonorGroup.archived => 'В архиве пока пусто.',
      DonorGroup.dismantled => 'Полностью разобранных машин пока нет.',
      DonorGroup.active when canManageDonors(context) =>
        'Купили машину на разбор? Добавьте её — детали, снятые с неё, '
            'пойдут на склад, а здесь будет видно, когда она окупится.',
      DonorGroup.active => 'Машин в разборе пока нет.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryFigure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DonorCard extends StatelessWidget {
  final DonorModel donor;
  final String? photoUrl;
  final VoidCallback onTap;

  const _DonorCard({required this.donor, this.photoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final economics = donor.economics;
    final meta = [
      donor.status.label,
      if (donor.vin != null) donor.vin!,
      if (donor.engineLabel != null) donor.engineLabel!,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const SizedBox(width: 48, height: 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donor.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (economics != null)
                    Text(
                      '${economics.realizedProfit >= 0 ? '+' : ''}${formatMoney(economics.realizedProfit)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: economics.realizedProfit >= 0
                            ? AppTheme.secondaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (economics != null) ...[
                DonorPaybackBar(economics: economics),
                const SizedBox(height: 8),
                Text(
                  'Окупаемость ${economics.paybackPercent?.toStringAsFixed(0) ?? '—'}% · '
                  'вернулось ${formatMoney(economics.income)} из ${formatMoney(economics.totalCost)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ] else
                Text(
                  'Снято деталей: ${donor.partsCount} · на складе: ${donor.unitsInStock} шт.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
