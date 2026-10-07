import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/donor_model.dart';
import 'package:autohub_b2b/screens/warehouse/donors_screen.dart'
    show formatMoney;
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/donor_service.dart';
import 'package:autohub_b2b/widgets/vehicle_reference_fields.dart';

/// Покупка машины на разбор или правка её данных и расходов.
class DonorFormScreen extends StatefulWidget {
  final DonorModel? donor;

  const DonorFormScreen({super.key, this.donor});

  @override
  State<DonorFormScreen> createState() => _DonorFormScreenState();
}

class _DonorFormScreenState extends State<DonorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DonorService();
  final _dateFormat = DateFormat('dd.MM.yyyy');

  int? _makeId;
  int? _modelId;
  int? _generationId;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _generation;
  late final TextEditingController _year;
  late final TextEditingController _vin;
  late final TextEditingController _engine;
  late final TextEditingController _engineVolume;
  late final TextEditingController _body;
  late final TextEditingController _color;
  late final TextEditingController _mileage;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _deliveryCost;
  late final TextEditingController _dismantlingCost;
  late final TextEditingController _otherCosts;
  late final TextEditingController _scrapIncome;
  late final TextEditingController _source;
  late final TextEditingController _notes;
  DonorTransmission? _transmission;
  DonorDrivetrain? _drivetrain;
  DateTime? _purchaseDate;
  DateTime? _dismantlingStartDate;
  DateTime? _dismantlingEndDate;
  bool _alreadyOnSite = false;
  bool _showCarDetails = false;
  bool _saving = false;

  bool get _isEdit => widget.donor != null;

  List<TextEditingController> get _controllers => [
    _brand,
    _model,
    _generation,
    _year,
    _vin,
    _engine,
    _engineVolume,
    _body,
    _color,
    _mileage,
    _purchasePrice,
    _deliveryCost,
    _dismantlingCost,
    _otherCosts,
    _scrapIncome,
    _source,
    _notes,
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.donor;
    String money(double? v) => v == null || v == 0 ? '' : v.toStringAsFixed(0);

    _brand = TextEditingController(text: d?.brand ?? '');
    _model = TextEditingController(text: d?.model ?? '');
    _generation = TextEditingController(text: d?.generation ?? '');
    _year = TextEditingController(text: d?.year?.toString() ?? '');
    _vin = TextEditingController(text: d?.vin ?? '');
    _engine = TextEditingController(text: d?.engine ?? '');
    _engineVolume = TextEditingController(
      text: d?.engineVolume?.toStringAsFixed(1) ?? '',
    );
    _body = TextEditingController(text: d?.body ?? '');
    _color = TextEditingController(text: d?.color ?? '');
    _mileage = TextEditingController(text: d?.mileage?.toString() ?? '');
    _purchasePrice = TextEditingController(text: money(d?.purchasePrice));
    _deliveryCost = TextEditingController(text: money(d?.deliveryCost));
    _dismantlingCost = TextEditingController(text: money(d?.dismantlingCost));
    _otherCosts = TextEditingController(text: money(d?.otherCosts));
    _scrapIncome = TextEditingController(text: money(d?.scrapIncome));
    _source = TextEditingController(text: d?.source ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _transmission = d?.transmission;
    _drivetrain = d?.drivetrain;
    _purchaseDate = d?.purchaseDate ?? (d == null ? DateTime.now() : null);
    _dismantlingStartDate = d?.dismantlingStartDate;
    _dismantlingEndDate = d?.dismantlingEndDate;
    _showCarDetails =
        d != null &&
        [
          d.engine,
          d.engineVolume,
          d.transmission,
          d.drivetrain,
          d.body,
          d.color,
          d.mileage,
        ].any((v) => v != null);

    for (final c in [
      _purchasePrice,
      _deliveryCost,
      _dismantlingCost,
      _otherCosts,
    ]) {
      c.addListener(_onCostChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCostChanged() => setState(() {});

  double _parseMoney(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

  double? _parseVolume() =>
      double.tryParse(_engineVolume.text.trim().replaceAll(',', '.'));

  double get _totalCost =>
      _parseMoney(_purchasePrice) +
      _parseMoney(_deliveryCost) +
      _parseMoney(_dismantlingCost) +
      _parseMoney(_otherCosts);

  String? _isoDate(DateTime? date) =>
      date == null ? null : DateFormat('yyyy-MM-dd').format(date);

  Map<String, dynamic> _payload() {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    int? number(TextEditingController c) => int.tryParse(c.text.trim());

    final data = <String, dynamic>{
      'brand': _brand.text.trim(),
      'model': _model.text.trim(),
      'generation': text(_generation),
      if (_makeId != null) 'makeId': _makeId,
      if (_modelId != null) 'modelId': _modelId,
      if (_generationId != null) 'generationId': _generationId,
      'year': number(_year),
      'vin': text(_vin),
      'engine': text(_engine),
      'engineVolume': _parseVolume(),
      'transmission': _transmission?.value,
      'drivetrain': _drivetrain?.value,
      'body': text(_body),
      'color': text(_color),
      'mileage': number(_mileage),
      'purchasePrice': _parseMoney(_purchasePrice),
      'deliveryCost': _parseMoney(_deliveryCost),
      'dismantlingCost': _parseMoney(_dismantlingCost),
      'otherCosts': _parseMoney(_otherCosts),
      'purchaseDate': _isoDate(_purchaseDate),
      'source': text(_source),
      'notes': text(_notes),
    };

    if (_isEdit) {
      // При правке null очищает поле.
      data['scrapIncome'] = _parseMoney(_scrapIncome);
      if (widget.donor!.dismantlingStartDate != null ||
          _dismantlingStartDate != null) {
        data['dismantlingStartDate'] = _isoDate(_dismantlingStartDate);
        data['dismantlingEndDate'] = _isoDate(_dismantlingEndDate);
      }
      return data;
    }

    if (_alreadyOnSite) {
      data['status'] = DonorStatus.waitingForDismantling.value;
    }
    data.removeWhere((key, value) => value == null);
    return data;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = _isEdit
          ? await _service.updateDonor(widget.donor!.id, _payload())
          : await _service.createDonor(_payload());
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingApiMessage(e, prefix: 'Не удалось сохранить'),
          ),
        ),
      );
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Данные донора' : 'Новый донор'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('Машина'),
                    VehicleReferenceFields(
                      initialMake: widget.donor?.brand,
                      initialModel: widget.donor?.model,
                      initialGeneration: widget.donor?.generation,
                      onChanged: (selection) {
                        _makeId = selection?.makeId;
                        _modelId = selection?.modelId;
                        _generationId = selection?.generationId;
                        _brand.text = selection?.make ?? '';
                        _model.text = selection?.model ?? '';
                        _generation.text = selection?.generation ?? '';
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _year,
                      'Год',
                      digitsOnly: true,
                      validator: _validateYear,
                    ),
                    _field(
                      _vin,
                      'VIN или номер кузова',
                      hint: 'Попадёт в описание каждой детали',
                      capitalize: true,
                    ),
                    if (_showCarDetails)
                      ..._buildCarDetails()
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _showCarDetails = true),
                          child: const Text(
                            'Двигатель, КПП, привод, кузов, пробег',
                          ),
                        ),
                      ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 8),
                      _section('Где машина'),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Куплена, едет'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Уже на площадке'),
                          ),
                        ],
                        selected: {_alreadyOnSite},
                        onSelectionChanged: (s) =>
                            setState(() => _alreadyOnSite = s.first),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    _section('Деньги'),
                    _field(
                      _purchasePrice,
                      'Цена покупки *',
                      suffix: '₸',
                      digitsOnly: true,
                      required: true,
                    ),
                    _row([
                      _field(
                        _deliveryCost,
                        'Доставка',
                        hint: 'Эвакуатор, растаможка',
                        suffix: '₸',
                        digitsOnly: true,
                      ),
                      _field(
                        _dismantlingCost,
                        'Разборка',
                        hint: 'Работа разборщиков',
                        suffix: '₸',
                        digitsOnly: true,
                      ),
                    ]),
                    _field(
                      _otherCosts,
                      'Прочие расходы',
                      suffix: '₸',
                      digitsOnly: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Себестоимость машины: ${formatMoney(_totalCost)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isEdit)
                      _field(
                        _scrapIncome,
                        'Доход вне склада',
                        hint: 'Кузов на металл, продажа остатков целиком',
                        suffix: '₸',
                        digitsOnly: true,
                      ),
                    _dateButton(
                      label: 'Дата покупки',
                      value: _purchaseDate,
                      onPick: () async {
                        final picked = await _pickDate(_purchaseDate);
                        if (picked != null) {
                          setState(() => _purchaseDate = picked);
                        }
                      },
                    ),
                    if (_isEdit && _dismantlingStartDate != null) ...[
                      _row([
                        _dateButton(
                          label: 'Начало разбора',
                          value: _dismantlingStartDate,
                          onPick: () async {
                            final picked = await _pickDate(
                              _dismantlingStartDate,
                            );
                            if (picked != null) {
                              setState(() => _dismantlingStartDate = picked);
                            }
                          },
                        ),
                        _dateButton(
                          label: 'Конец разбора',
                          value: _dismantlingEndDate,
                          onPick: () async {
                            final picked = await _pickDate(
                              _dismantlingEndDate ?? DateTime.now(),
                              first: _dismantlingStartDate,
                            );
                            if (picked != null) {
                              setState(() => _dismantlingEndDate = picked);
                            }
                          },
                        ),
                      ]),
                    ],
                    _field(_source, 'Где куплен', hint: 'Аукцион, продавец'),
                    _field(_notes, 'Заметки', maxLines: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCarDetails() => [
    _row([
      _field(_engine, 'Двигатель', hint: '2AR-FE', capitalize: true),
      _field(
        _engineVolume,
        'Объём, л',
        hint: '2.5',
        decimal: true,
        validator: _validateVolume,
      ),
    ]),
    _row([
      _dropdown<DonorTransmission>(
        label: 'КПП',
        value: _transmission,
        values: DonorTransmission.values,
        labelOf: (t) => t.label,
        onChanged: (v) => setState(() => _transmission = v),
      ),
      _dropdown<DonorDrivetrain>(
        label: 'Привод',
        value: _drivetrain,
        values: DonorDrivetrain.values,
        labelOf: (d) => d.label,
        onChanged: (v) => setState(() => _drivetrain = v),
      ),
    ]),
    _row([
      _field(_body, 'Кузов', hint: 'Седан, ACV40'),
      _field(_color, 'Цвет'),
    ]),
    _field(_mileage, 'Пробег, км', digitsOnly: true),
  ];

  String? _validateYear(String? value) {
    if (value == null || value.isEmpty) return null;
    final year = int.tryParse(value);
    if (year == null || year < 1950 || year > DateTime.now().year + 1) {
      return 'Некорректный год';
    }
    return null;
  }

  String? _validateVolume(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final volume = _parseVolume();
    if (volume == null || volume < 0.1 || volume > 20) return 'Например, 2.5';
    return null;
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _row(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 480) return Column(children: children);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );

  Widget _dateButton({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
        ),
        child: Text(
          value == null ? label : '$label: ${_dateFormat.format(value)}',
          style: value == null
              ? const TextStyle(color: AppTheme.textSecondary)
              : null,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Не указано')),
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(labelOf(v))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? suffix,
    bool required = false,
    bool digitsOnly = false,
    bool decimal = false,
    bool capitalize = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : digitsOnly
            ? TextInputType.number
            : null,
        textCapitalization: capitalize
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        validator:
            validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Обязательно' : null
                : null),
      ),
    );
  }
}
