import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

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
  final _dio = ApiClient().dio;
  final _yearFrom = TextEditingController();
  final _yearTo = TextEditingController();
  final _body = TextEditingController();
  final _engine = TextEditingController();
  final _transmission = TextEditingController();

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _generations = [];
  String? _brandSlug;
  String? _brandName;
  String? _modelSlug;
  String? _modelName;
  Map<String, dynamic>? _generation;
  bool _loadingBrands = true;
  bool _loadingModels = false;
  bool _loadingGenerations = false;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    for (final c in [_yearFrom, _yearTo, _body, _engine, _transmission]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _named(List<Map<String, dynamic>> list, String? name) {
    final want = name?.trim().toLowerCase();
    if (want == null || want.isEmpty) return null;
    for (final row in list) {
      if ((row['name'] as String?)?.toLowerCase() == want) return row;
    }
    return null;
  }

  Future<void> _loadBrands() async {
    try {
      final response = await _dio.get('/api/auto-data/brands');
      final list = List<Map<String, dynamic>>.from(response.data as List);
      if (!mounted) return;
      final match = _named(list, widget.initial?.make);
      setState(() {
        _brands = list;
        _loadingBrands = false;
        _catalogError = list.isEmpty ? 'Справочник марок пуст' : null;
        if (match != null) {
          _brandSlug = match['slug'] as String;
          _brandName = match['name'] as String;
        }
      });
      if (_brandSlug != null) await _loadModels(_brandSlug!, keepInitial: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBrands = false;
        _catalogError = userFacingApiMessage(e, prefix: 'Марки не загрузились');
      });
    }
  }

  Future<void> _loadModels(String brandSlug, {bool keepInitial = false}) async {
    setState(() {
      _loadingModels = true;
      _models = [];
      _generations = [];
      _modelSlug = null;
      _modelName = null;
      _generation = null;
    });
    try {
      final response = await _dio.get(
        '/api/auto-data/brands/$brandSlug/models',
      );
      final list = List<Map<String, dynamic>>.from(
        response.data as List? ?? [],
      );
      if (!mounted) return;
      final match = keepInitial ? _named(list, widget.initial?.model) : null;
      setState(() {
        _models = list;
        _loadingModels = false;
        if (match != null) {
          _modelSlug = match['slug'] as String;
          _modelName = match['name'] as String;
        }
      });
      if (_modelSlug != null) {
        await _loadGenerations(
          brandSlug,
          _modelSlug!,
          keepInitial: keepInitial,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingApiMessage(e, prefix: 'Модели не загрузились'),
          ),
        ),
      );
    }
  }

  Future<void> _loadGenerations(
    String brandSlug,
    String modelSlug, {
    bool keepInitial = false,
  }) async {
    setState(() {
      _loadingGenerations = true;
      _generations = [];
      _generation = null;
    });
    try {
      final response = await _dio.get(
        '/api/auto-data/brands/$brandSlug/models/$modelSlug/generations',
      );
      final list = List<Map<String, dynamic>>.from(
        response.data as List? ?? [],
      );
      if (!mounted) return;
      setState(() {
        _generations = list;
        _loadingGenerations = false;
        if (keepInitial) {
          _generation = _named(list, widget.initial?.generation);
          _applyGenerationYears(_generation);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGenerations = false);
    }
  }

  void _applyGenerationYears(Map<String, dynamic>? generation) {
    if (generation == null) return;
    final from = generation['year_from'];
    final to = generation['year_to'];
    if (from != null) _yearFrom.text = '$from';
    if (to != null) _yearTo.text = '$to';
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
    if (_brandName == null || _modelName == null) return;
    Navigator.of(context).pop(
      ItemCompatibility(
        make: _brandName!,
        model: _modelName!,
        generation: _generation?['name'] as String?,
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
                if (_loadingBrands)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_catalogError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _catalogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.errorColor,
                      ),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _brandSlug,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Марка *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final brand in _brands)
                        DropdownMenuItem(
                          value: brand['slug'] as String,
                          child: Text(brand['name'] as String),
                        ),
                    ],
                    onChanged: (slug) {
                      if (slug == null) return;
                      setState(() {
                        _brandSlug = slug;
                        _brandName =
                            _brands.firstWhere((b) => b['slug'] == slug)['name']
                                as String;
                      });
                      _loadModels(slug);
                    },
                    validator: (v) => v == null ? 'Выберите марку' : null,
                  ),
                  if (_brandSlug != null) ...[
                    gap,
                    if (_loadingModels)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _modelSlug,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Модель *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final model in _models)
                            DropdownMenuItem(
                              value: model['slug'] as String,
                              child: Text(model['name'] as String),
                            ),
                        ],
                        onChanged: (slug) {
                          if (slug == null || _brandSlug == null) return;
                          setState(() {
                            _modelSlug = slug;
                            _modelName =
                                _models.firstWhere(
                                      (m) => m['slug'] == slug,
                                    )['name']
                                    as String;
                          });
                          _loadGenerations(_brandSlug!, slug);
                        },
                        validator: (v) => v == null ? 'Выберите модель' : null,
                      ),
                  ],
                  if (_modelSlug != null && _loadingGenerations) ...[
                    gap,
                    const LinearProgressIndicator(),
                  ] else if (_generations.isNotEmpty) ...[
                    gap,
                    DropdownButtonFormField<String>(
                      initialValue: _generation?['id']?.toString(),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Поколение',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final generation in _generations)
                          DropdownMenuItem(
                            value: generation['id']?.toString(),
                            child: Text(generation['name'] as String),
                          ),
                      ],
                      onChanged: (id) {
                        Map<String, dynamic>? picked;
                        for (final generation in _generations) {
                          if (generation['id']?.toString() == id) {
                            picked = generation;
                            break;
                          }
                        }
                        setState(() => _generation = picked);
                        _applyGenerationYears(picked);
                      },
                    ),
                  ],
                ],
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
          onPressed: _brandName == null || _modelName == null ? null : _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
