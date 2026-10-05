import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/donor_model.dart';
import 'package:autohub_b2b/screens/warehouse/donor_form_screen.dart';
import 'package:autohub_b2b/screens/warehouse/donors_screen.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/donor_service.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';

const _typicalParts = [
  'Двигатель',
  'КПП',
  'Турбина',
  'Генератор',
  'Стартер',
  'Компрессор кондиционера',
  'Радиатор',
  'ЭБУ двигателя',
  'Блок ABS',
  'Топливный насос',
  'Фара левая',
  'Фара правая',
  'Фонарь левый',
  'Фонарь правый',
  'Бампер передний',
  'Бампер задний',
  'Капот',
  'Крыло переднее левое',
  'Крыло переднее правое',
  'Дверь передняя левая',
  'Дверь передняя правая',
  'Дверь задняя левая',
  'Дверь задняя правая',
  'Крышка багажника',
  'Зеркало левое',
  'Зеркало правое',
  'Стекло лобовое',
  'Панель приборов',
  'Руль',
  'Подушка безопасности водителя',
  'Сиденье водителя',
  'Стойка передняя левая',
  'Стойка передняя правая',
  'Суппорт передний левый',
  'Суппорт передний правый',
  'Диск колёсный',
];

class DonorDetailScreen extends StatefulWidget {
  final int donorId;

  const DonorDetailScreen({super.key, required this.donorId});

  @override
  State<DonorDetailScreen> createState() => _DonorDetailScreenState();
}

class _DonorDetailScreenState extends State<DonorDetailScreen> {
  final DonorService _service = DonorService();
  DonorModel? _donor;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _donor == null;
      _error = null;
    });
    try {
      final donor = await _service.getDonor(widget.donorId);
      if (mounted) {
        setState(() {
          _donor = donor;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  void _showError(Object e, String prefix) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e, prefix: prefix))));
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<DonorModel>(
      MaterialPageRoute(builder: (_) => DonorFormScreen(donor: _donor)),
    );
    if (updated != null && mounted) setState(() => _donor = updated);
  }

  Future<void> _changeStatus(DonorStatus status) async {
    if (status == DonorStatus.closed) {
      final confirm = await DialogHelper.showConfirmSimple(
        context: context,
        title: 'Закрыть учёт?',
        message:
            'Детали останутся на складе и продолжат продаваться, но снимать '
            'новые с этой машины будет нельзя. Если сдали кузов на металл — '
            'внесите сумму в «Доход вне склада».',
        confirmText: 'Закрыть',
      );
      if (confirm != true) return;
    }
    try {
      final updated = await _service.updateDonor(widget.donorId, {
        'status': status.value,
      });
      if (mounted) setState(() => _donor = updated);
    } catch (e) {
      if (mounted) _showError(e, 'Не удалось сменить статус');
    }
  }

  Future<void> _delete() async {
    final confirm = await DialogHelper.showConfirmSimple(
      context: context,
      title: 'Удалить донора?',
      message: 'Запись о покупке будет удалена.',
      confirmText: 'Удалить',
      isDestructive: true,
    );
    if (confirm != true) return;
    try {
      await _service.deleteDonor(widget.donorId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError(e, 'Не удалось удалить');
    }
  }

  Future<void> _addParts() async {
    if (!await ensureAuthenticated(context)) return;
    if (!mounted || _donor == null) return;
    final added = await showDialog<int>(
      context: context,
      builder: (_) => _AddPartDialog(
        service: _service,
        donor: _donor!,
      ),
    );
    if (added != null && added > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('На склад добавлено деталей: $added')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final donor = _donor;
    final canManage = canManageDonors(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(donor?.title ?? 'Донор'),
        actions: [
          if (donor != null && canManage) ...[
            IconButton(
              tooltip: 'Изменить данные и расходы',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'delete'
                  ? _delete()
                  : _changeStatus(DonorStatus.fromValue(value)),
              itemBuilder: (_) => [
                for (final status in DonorStatus.values)
                  if (status != donor.status && status != DonorStatus.awaiting)
                    PopupMenuItem(
                      value: status.value,
                      child: Text(switch (status) {
                        DonorStatus.dismantling =>
                          donor.status == DonorStatus.awaiting
                              ? 'Начать разбор'
                              : 'Вернуть в разбор',
                        DonorStatus.dismantled => 'Разобран полностью',
                        DonorStatus.closed => 'Закрыть учёт',
                        DonorStatus.awaiting => status.label,
                      }),
                    ),
                if (donor.partsCount == 0)
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: donor != null && !donor.isClosed
          ? FloatingActionButton.extended(
              onPressed: _addParts,
              icon: const Icon(Icons.add),
              label: const Text('Снять деталь'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _donor == null) {
      if (isNetworkError(_error!)) return OfflinePlaceholder(onRetry: _load);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(userFacingApiMessage(_error!), textAlign: TextAlign.center),
        ),
      );
    }

    final donor = _donor!;
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
                  _buildInfo(donor),
                  const SizedBox(height: 16),
                  _DonorPhotos(
                    donor: donor,
                    service: _service,
                    onChanged: (updated) => setState(() => _donor = updated),
                  ),
                  if (donor.economics != null) ...[
                    const SizedBox(height: 24),
                    _EconomicsSection(donor: donor),
                  ],
                  const SizedBox(height: 24),
                  _buildParts(donor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(DonorModel donor) {
    final theme = Theme.of(context);
    final facts = [
      donor.status.label,
      if (donor.vin != null) donor.vin!,
      if (donor.engine != null) donor.engine!,
      if (donor.mileage != null)
        '${NumberFormat.decimalPattern('ru_RU').format(donor.mileage)} км',
      if (donor.color != null) donor.color!,
      if (donor.purchaseDate != null)
        'куплен ${DateFormat('dd.MM.yyyy').format(donor.purchaseDate!)}',
      if (donor.source != null) donor.source!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          facts.join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        if (donor.notes != null) ...[
          const SizedBox(height: 8),
          Text(donor.notes!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildParts(DonorModel donor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Снятые детали · ${donor.parts.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (donor.parts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              donor.isClosed
                  ? 'С этой машины ничего не снимали.'
                  : 'Снимайте детали по одной — каждая сразу появится на складе '
                        'с пометкой, с какой машины она снята.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          )
        else
          for (final part in donor.parts) ...[
            _PartRow(part: part),
            const Divider(height: 1),
          ],
      ],
    );
  }
}

class _EconomicsSection extends StatelessWidget {
  final DonorModel donor;

  const _EconomicsSection({required this.donor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = donor.economics!;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textSecondary,
    );

    final String headline;
    if (e.isPaidBack) {
      headline = 'Окупился, прибыль ${formatMoney(e.profit)}';
    } else {
      headline = 'Осталось вернуть ${formatMoney(-e.profit)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: e.isPaidBack ? AppTheme.secondaryColor : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Окупаемость ${e.paybackPercent?.toStringAsFixed(0) ?? '—'}%',
            style: muted,
          ),
          const SizedBox(height: 12),
          DonorPaybackBar(economics: e),
          const SizedBox(height: 16),
          _line(context, 'Покупка', donor.purchasePrice ?? 0),
          _line(context, 'Доп. расходы', donor.extraCosts ?? 0),
          _line(context, 'Вложено всего', e.totalCost, bold: true),
          const SizedBox(height: 8),
          _line(
            context,
            'Продано деталей · ${donor.unitsSold} шт.',
            e.soldRevenue,
          ),
          if (e.scrapIncome > 0)
            _line(context, 'Доход вне склада', e.scrapIncome),
          _line(context, 'Вернулось всего', e.income, bold: true),
          const Divider(height: 24),
          _line(
            context,
            'На складе · ${donor.unitsInStock} шт.',
            e.stockValue,
          ),
          if (e.pendingRevenue > 0)
            _line(context, 'В открытых заказах', e.pendingRevenue),
          _line(
            context,
            'Если продать остатки по текущим ценам',
            e.forecastProfit,
            bold: true,
            signed: true,
          ),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    double value, {
    bool bold = false,
    bool signed = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w600 : null,
    );
    final text = signed && value > 0
        ? '+${formatMoney(value)}'
        : formatMoney(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 16),
          Text(text, style: style),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  final DonorPart part;

  const _PartRow({required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textSecondary,
    );
    final meta = [
      if (part.warehouseCell != null) 'ячейка ${part.warehouseCell}',
      if (part.category != null) part.category!,
      if (part.unitCost != null) 'себестоимость ${formatMoney(part.unitCost!)}',
    ].join(' · ');
    final profit = part.realizedProfit;
    final stockText = [
      if (part.soldQuantity > 0) 'продано ${part.soldQuantity}',
      part.quantity > 0 ? 'в наличии ${part.quantity}' : 'нет в наличии',
      if (part.soldQuantity > 0 && profit != null)
        'прибыль ${profit > 0 ? '+' : ''}${formatMoney(profit)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.name, style: theme.textTheme.bodyLarge),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: muted),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(part.price), style: theme.textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(stockText, style: muted),
            ],
          ),
        ],
      ),
    );
  }
}

/// Быстрый ввод снятых деталей подряд: ячейка и категория запоминаются между деталями.
class _AddPartDialog extends StatefulWidget {
  final DonorService service;
  final DonorModel donor;

  const _AddPartDialog({required this.service, required this.donor});

  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _cell = TextEditingController();
  final _category = TextEditingController();
  // Поле названия принадлежит Autocomplete; держим ссылки, чтобы очищать его и возвращать фокус.
  TextEditingController? _name;
  FocusNode? _nameFocus;
  int _added = 0;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    _cell.dispose();
    _category.dispose();
    super.dispose();
  }

  Iterable<String> _suggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final taken = widget.donor.parts.map((p) => p.name.toLowerCase()).toSet();
    return _typicalParts
        .where((name) => name.toLowerCase().contains(q))
        .where((name) => !taken.contains(name.toLowerCase()))
        .take(8);
  }

  Future<void> _save({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.addParts(widget.donor.id, [
        {
          'name': _name!.text.trim(),
          'price': double.parse(_price.text),
          'quantity': int.tryParse(_quantity.text) ?? 1,
          if (_cell.text.trim().isNotEmpty) 'warehouseCell': _cell.text.trim(),
          if (_category.text.trim().isNotEmpty)
            'category': _category.text.trim(),
        },
      ]);
      _added++;
      if (!mounted) return;
      if (!addAnother) {
        Navigator.of(context).pop(_added);
        return;
      }
      setState(() => _saving = false);
      _name!.clear();
      _price.clear();
      _quantity.text = '1';
      _nameFocus?.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingApiMessage(e, prefix: 'Деталь не сохранена')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Снять деталь'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _added == 0
                      ? widget.donor.title
                      : '${widget.donor.title} · добавлено: $_added',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (value) => _suggestions(value.text),
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    _name = controller;
                    _nameFocus = focusNode;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Название *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Обязательно' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Цена продажи *',
                          suffixText: '₸',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Укажите цену'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Кол-во',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                            ? 'Мин. 1'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cell,
                        decoration: const InputDecoration(
                          labelText: 'Ячейка',
                          hintText: 'A-12',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          hintText: 'Кузов, двигатель…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(_added),
          child: Text(_added == 0 ? 'Отмена' : 'Готово'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(addAnother: true),
          child: const Text('Сохранить и ещё'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(addAnother: false),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

const _maxDonorPhotos = 20;
const _photoSize = 96.0;

/// Фото машины при покупке: состояние кузова, повреждения, VIN-табличка.
class _DonorPhotos extends StatefulWidget {
  final DonorModel donor;
  final DonorService service;
  final ValueChanged<DonorModel> onChanged;

  const _DonorPhotos({
    required this.donor,
    required this.service,
    required this.onChanged,
  });

  @override
  State<_DonorPhotos> createState() => _DonorPhotosState();
}

class _DonorPhotosState extends State<_DonorPhotos> {
  final _picker = ImagePicker();
  bool _uploading = false;

  int get _slotsLeft => _maxDonorPhotos - widget.donor.photos.length;

  Future<void> _add() async {
    if (!await ensureAuthenticated(context)) return;
    final files = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    try {
      final updated = await widget.service.uploadPhotos(
        widget.donor.id,
        files.take(_slotsLeft).toList(),
      );
      widget.onChanged(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Фото не загружены')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(String path) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: widget.service.photoUrl(path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('Удалить'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    try {
      widget.onChanged(await widget.service.removePhoto(widget.donor.id, path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiMessage(e, prefix: 'Фото не удалено')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.donor.photos;
    return SizedBox(
      height: _photoSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (_slotsLeft > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == photos.length) return _buildAddTile();
          final path = photos[index];
          return Semantics(
            button: true,
            label: 'Фото ${index + 1}',
            child: InkWell(
              onTap: () => _open(path),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.service.photoUrl(path),
                  width: _photoSize,
                  height: _photoSize,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppTheme.borderColor),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.borderColor,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddTile() {
    return Tooltip(
      message: 'Добавить фото',
      child: InkWell(
        onTap: _uploading ? null : _add,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: _photoSize,
          height: _photoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Center(
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Фото',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
