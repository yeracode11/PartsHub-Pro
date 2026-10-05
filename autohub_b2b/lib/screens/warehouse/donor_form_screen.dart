import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/models/donor_model.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/donor_service.dart';

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

  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _vin;
  late final TextEditingController _engine;
  late final TextEditingController _color;
  late final TextEditingController _mileage;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _extraCosts;
  late final TextEditingController _scrapIncome;
  late final TextEditingController _source;
  late final TextEditingController _notes;
  DateTime? _purchaseDate;
  bool _saving = false;

  bool get _isEdit => widget.donor != null;

  @override
  void initState() {
    super.initState();
    final d = widget.donor;
    String money(double? v) => v == null || v == 0 ? '' : v.toStringAsFixed(0);

    _brand = TextEditingController(text: d?.brand ?? '');
    _model = TextEditingController(text: d?.model ?? '');
    _year = TextEditingController(text: d?.year?.toString() ?? '');
    _vin = TextEditingController(text: d?.vin ?? '');
    _engine = TextEditingController(text: d?.engine ?? '');
    _color = TextEditingController(text: d?.color ?? '');
    _mileage = TextEditingController(text: d?.mileage?.toString() ?? '');
    _purchasePrice = TextEditingController(text: money(d?.purchasePrice));
    _extraCosts = TextEditingController(text: money(d?.extraCosts));
    _scrapIncome = TextEditingController(text: money(d?.scrapIncome));
    _source = TextEditingController(text: d?.source ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _purchaseDate = d?.purchaseDate ?? (d == null ? DateTime.now() : null);
  }

  @override
  void dispose() {
    for (final c in [
      _brand,
      _model,
      _year,
      _vin,
      _engine,
      _color,
      _mileage,
      _purchasePrice,
      _extraCosts,
      _scrapIncome,
      _source,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parseMoney(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

  Map<String, dynamic> _payload() {
    // При правке пустая строка очищает поле; при создании пустые поля не шлём.
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty && !_isEdit ? null : c.text.trim();
    int? number(TextEditingController c) => int.tryParse(c.text.trim());

    final data = <String, dynamic>{
      'brand': _brand.text.trim(),
      'model': _model.text.trim(),
      'year': number(_year),
      'vin': text(_vin) ?? '',
      'engine': text(_engine),
      'color': text(_color),
      'mileage': number(_mileage),
      'purchasePrice': _parseMoney(_purchasePrice),
      'extraCosts': _parseMoney(_extraCosts),
      'scrapIncome': _parseMoney(_scrapIncome),
      'purchaseDate': _purchaseDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_purchaseDate!),
      'source': text(_source),
      'notes': text(_notes),
    };
    // Пустые необязательные поля не отправляем: валидатор не принимает null.
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
          content: Text(userFacingApiMessage(e, prefix: 'Не удалось сохранить')),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
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
                    _row([
                      _field(_brand, 'Марка *', required: true),
                      _field(_model, 'Модель *', required: true),
                    ]),
                    _row([
                      _field(
                        _year,
                        'Год',
                        digitsOnly: true,
                        validator: _validateYear,
                      ),
                      _field(_engine, 'Двигатель', hint: '2AR-FE'),
                    ]),
                    _field(
                      _vin,
                      'VIN или номер кузова',
                      hint: 'Попадёт в описание каждой детали',
                      capitalize: true,
                    ),
                    _row([
                      _field(_color, 'Цвет'),
                      _field(_mileage, 'Пробег, км', digitsOnly: true),
                    ]),
                    const SizedBox(height: 8),
                    _section('Деньги'),
                    _field(
                      _purchasePrice,
                      'Цена покупки *',
                      suffix: '₸',
                      digitsOnly: true,
                      required: true,
                    ),
                    _field(
                      _extraCosts,
                      'Доп. расходы',
                      hint: 'Доставка, растаможка, эвакуатор, разборка',
                      suffix: '₸',
                      digitsOnly: true,
                    ),
                    if (_isEdit)
                      _field(
                        _scrapIncome,
                        'Доход вне склада',
                        hint: 'Кузов на металл, продажа остатков целиком',
                        suffix: '₸',
                        digitsOnly: true,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Text(
                          _purchaseDate == null
                              ? 'Дата покупки'
                              : 'Куплен ${DateFormat('dd.MM.yyyy').format(_purchaseDate!)}',
                        ),
                      ),
                    ),
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

  String? _validateYear(String? value) {
    if (value == null || value.isEmpty) return null;
    final year = int.tryParse(value);
    if (year == null || year < 1950 || year > DateTime.now().year + 1) {
      return 'Некорректный год';
    }
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

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? suffix,
    bool required = false,
    bool digitsOnly = false,
    bool capitalize = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: digitsOnly ? TextInputType.number : null,
        textCapitalization: capitalize
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
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
