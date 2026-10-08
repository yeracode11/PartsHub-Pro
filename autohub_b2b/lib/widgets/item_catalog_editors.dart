import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/widgets/vehicle_reference_fields.dart';

const _maxRows = 50;

/// Номера, под которыми ещё ищут деталь: другие оригинальные и неоригинальные аналоги.
class CrossReferencesEditor extends StatelessWidget {
  final List<ItemCrossReference> value;
  final ValueChanged<List<ItemCrossReference>> onChanged;

  const CrossReferencesEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final added = await showDialog<ItemCrossReference>(
      context: context,
      builder: (_) => const _CrossReferenceDialog(),
    );
    if (added == null) return;
    final key = normalizeOem(added.oem);
    onChanged([...value.where((r) => normalizeOem(r.oem) != key), added]);
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Аналоги',
      emptyText: 'Добавьте другие номера этой детали — по ним её тоже найдут.',
      addLabel: 'Добавить номер',
      canAdd: value.length < _maxRows,
      onAdd: () => _add(context),
      rows: [
        for (final ref in value)
          _EditorRow(
            title: ref.oem,
            subtitle: [
              if (ref.brand != null) ref.brand!,
              ref.isAftermarket ? 'неоригинал' : 'оригинальный номер',
            ].join(' · '),
            onRemove: () => onChanged([...value]..remove(ref)),
          ),
      ],
    );
  }
}

/// На какие машины подходит деталь.
class CompatibilityEditor extends StatelessWidget {
  final List<ItemCompatibility> value;
  final ValueChanged<List<ItemCompatibility>> onChanged;

  const CompatibilityEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final added = await showDialog<ItemCompatibility>(
      context: context,
      // Следующая строка чаще всего — та же марка и модель другого поколения.
      builder: (_) =>
          _CompatibilityDialog(initial: value.isEmpty ? null : value.last),
    );
    if (added == null || value.contains(added)) return;
    onChanged([...value, added]);
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Применимость',
      emptyText: 'Укажите машины, на которые подходит деталь.',
      addLabel: 'Добавить машину',
      canAdd: value.length < _maxRows,
      onAdd: () => _add(context),
      rows: [
        for (final fit in value)
          _EditorRow(
            title: fit.title,
            subtitle: fit.details,
            onRemove: () => onChanged([...value]..remove(fit)),
          ),
      ],
    );
  }
}

class _EditorSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final String addLabel;
  final bool canAdd;
  final VoidCallback onAdd;
  final List<Widget> rows;

  const _EditorSection({
    required this.title,
    required this.emptyText,
    required this.addLabel,
    required this.canAdd,
    required this.onAdd,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          )
        else
          ...rows,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

class _EditorRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onRemove;

  const _EditorRow({
    required this.title,
    this.subtitle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }
}

String? _optional(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

class _CrossReferenceDialog extends StatefulWidget {
  const _CrossReferenceDialog();

  @override
  State<_CrossReferenceDialog> createState() => _CrossReferenceDialogState();
}

class _CrossReferenceDialogState extends State<_CrossReferenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oem = TextEditingController();
  final _brand = TextEditingController();
  bool _aftermarket = false;

  @override
  void dispose() {
    _oem.dispose();
    _brand.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ItemCrossReference(
        oem: _oem.text.trim(),
        brand: _optional(_brand),
        type: _aftermarket ? 'aftermarket' : 'alternative',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Номер аналога'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _oem,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Номер *',
                  hintText: '04465-33450',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    normalizeOem(v ?? '').isEmpty ? 'Введите номер' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: 'Производитель',
                  hintText: 'Lexus, TRW…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Оригинал')),
                  ButtonSegment(value: true, label: Text('Неоригинал')),
                ],
                selected: {_aftermarket},
                onSelectionChanged: (s) =>
                    setState(() => _aftermarket = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Добавить')),
      ],
    );
  }
}

class _CompatibilityDialog extends StatefulWidget {
  final ItemCompatibility? initial;

  const _CompatibilityDialog({this.initial});

  @override
  State<_CompatibilityDialog> createState() => _CompatibilityDialogState();
}

class _CompatibilityDialogState extends State<_CompatibilityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yearFrom = TextEditingController();
  final _yearTo = TextEditingController();
  final _body = TextEditingController();
  final _engine = TextEditingController();
  final _transmission = TextEditingController();

  VehicleSelection? _car;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _yearFrom.text = initial.yearFrom?.toString() ?? '';
    _yearTo.text = initial.yearTo?.toString() ?? '';
    _body.text = initial.body ?? '';
    _engine.text = initial.engine ?? '';
    _transmission.text = initial.transmission ?? '';
    if (initial.make.isNotEmpty && initial.model.isNotEmpty) {
      _car = VehicleSelection(
        makeId: initial.makeId ?? 0,
        make: initial.make,
        modelId: initial.modelId ?? 0,
        model: initial.model,
        generationId: initial.generationId,
        generation: initial.generation,
        yearFrom: initial.yearFrom,
        yearTo: initial.yearTo,
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_yearFrom, _yearTo, _body, _engine, _transmission]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _yearError(String? value) {
    if (value == null || value.isEmpty) return null;
    final year = int.tryParse(value);
    final max = DateTime.now().year + 1;
    return year == null || year < 1950 || year > max ? '1950–$max' : null;
  }

  String? _yearToError(String? value) {
    final from = int.tryParse(_yearFrom.text);
    final to = int.tryParse(value ?? '');
    if (from != null && to != null && to < from) return 'Раньше, чем «с»';
    return _yearError(value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final car = _car;
    if (car == null) return;
    Navigator.of(context).pop(
      ItemCompatibility(
        make: car.make,
        model: car.model,
        generation: car.generation,
        makeId: car.makeId > 0 ? car.makeId : null,
        modelId: car.modelId > 0 ? car.modelId : null,
        generationId: car.generationId,
        yearFrom: int.tryParse(_yearFrom.text),
        yearTo: int.tryParse(_yearTo.text),
        body: _optional(_body),
        engine: _optional(_engine),
        transmission: _optional(_transmission),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
    bool year = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: year ? TextInputType.number : null,
      inputFormatters: year
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ]
          : null,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Обязательно';
        if (!year) return null;
        return controller == _yearTo ? _yearToError(v) : _yearError(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 16, height: 16);
    return AlertDialog(
      title: const Text('Подходит на машину'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VehicleReferenceFields(
                  initialMake: _car?.make,
                  initialModel: _car?.model,
                  initialGeneration: _car?.generation,
                  onChanged: (selection) {
                    setState(() => _car = selection);
                    final from = selection?.yearFrom;
                    final to = selection?.yearTo;
                    if (from != null) _yearFrom.text = '$from';
                    if (to != null) _yearTo.text = '$to';
                  },
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _field(_yearFrom, 'Год с', year: true)),
                    gap,
                    Expanded(child: _field(_yearTo, 'Год по', year: true)),
                  ],
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _field(_body, 'Кузов')),
                    gap,
                    Expanded(child: _field(_engine, 'Двигатель', hint: '2.5')),
                  ],
                ),
                gap,
                _field(_transmission, 'КПП', hint: 'автомат'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _car == null ? null : _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
