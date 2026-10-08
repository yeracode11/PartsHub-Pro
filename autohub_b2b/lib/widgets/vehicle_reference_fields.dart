import 'dart:async';

import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

class VehicleSelection {
  const VehicleSelection({
    required this.makeId,
    required this.make,
    required this.modelId,
    required this.model,
    this.generationId,
    this.generation,
    this.yearFrom,
    this.yearTo,
  });

  final int makeId;
  final String make;
  final int modelId;
  final String model;
  final int? generationId;
  final String? generation;
  final int? yearFrom;
  final int? yearTo;

  String get label {
    return [
      make,
      model,
      generation,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  }
}

enum _Step { make, model, generation }

/// Полноэкранный поиск: марка, затем модель, затем поколение.
class VehiclePickerPage extends StatefulWidget {
  const VehiclePickerPage({super.key});

  static Future<VehicleSelection?> open(BuildContext context) {
    return Navigator.of(context).push<VehicleSelection>(
      MaterialPageRoute(builder: (_) => const VehiclePickerPage()),
    );
  }

  @override
  State<VehiclePickerPage> createState() => _VehiclePickerPageState();
}

class _VehiclePickerPageState extends State<VehiclePickerPage> {
  final _dio = ApiClient().dio;
  final _search = TextEditingController();
  Timer? _debounce;

  _Step _step = _Step.make;
  Map<String, dynamic>? _make;
  Map<String, dynamic>? _model;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _title {
    switch (_step) {
      case _Step.make:
        return 'Марка';
      case _Step.model:
        return 'Модель';
      case _Step.generation:
        return 'Поколение';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _search.text.trim();
      final params = {if (query.isNotEmpty) 'search': query};
      final url = switch (_step) {
        _Step.make => '/api/vehicles/makes',
        _Step.model => '/api/vehicles/makes/${_make!['id']}/models',
        _Step.generation => '/api/vehicles/models/${_model!['id']}/generations',
      };
      final response = await _dio.get(url, queryParameters: params);
      final items = List<Map<String, dynamic>>.from(
        (response.data['items'] as List?) ?? [],
      );
      if (!mounted) return;
      if (_step == _Step.generation && items.isEmpty && query.isEmpty) {
        Navigator.of(context).pop(_selection(null));
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingApiMessage(e);
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  VehicleSelection _selection(Map<String, dynamic>? generation) {
    return VehicleSelection(
      makeId: _make!['id'] as int,
      make: _make!['name'] as String,
      modelId: _model!['id'] as int,
      model: _model!['name'] as String,
      generationId: generation?['id'] as int?,
      generation: generation?['name'] as String?,
      yearFrom: generation?['yearFrom'] as int?,
      yearTo: generation?['yearTo'] as int?,
    );
  }

  Future<void> _openMake(Map<String, dynamic> make) async {
    _search.clear();
    setState(() {
      _make = make;
      _model = null;
      _step = _Step.model;
    });
    await _load();
  }

  Future<void> _openModel(Map<String, dynamic> model) async {
    _search.clear();
    setState(() {
      _model = model;
      _step = _Step.generation;
    });
    await _load();
  }

  Future<void> _back() async {
    _search.clear();
    setState(() {
      if (_step == _Step.generation) {
        _step = _Step.model;
      } else {
        _step = _Step.make;
        _make = null;
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.make,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(_title),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_step == _Step.make) {
                Navigator.of(context).pop();
              } else {
                _back();
              }
            },
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: _step == _Step.make,
                decoration: const InputDecoration(
                  hintText: 'Поиск',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onSearch,
              ),
            ),
            if (_make != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _model == null
                        ? _make!['name'] as String
                        : '${_make!['name']} · ${_model!['name']}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    final showSkip = _step == _Step.generation && _search.text.trim().isEmpty;
    return ListView.separated(
      itemCount: _items.length + (showSkip ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (showSkip && index == 0) {
          return ListTile(
            title: const Text('Не указывать'),
            onTap: () => Navigator.of(context).pop(_selection(null)),
          );
        }
        final row = _items[showSkip ? index - 1 : index];
        final years = _step == _Step.generation ? _years(row) : '';
        return ListTile(
          title: Text('${row['name']}$years'),
          onTap: () {
            switch (_step) {
              case _Step.make:
                _openMake(row);
              case _Step.model:
                _openModel(row);
              case _Step.generation:
                Navigator.of(context).pop(_selection(row));
            }
          },
        );
      },
    );
  }

  String _years(Map<String, dynamic> row) {
    final from = row['yearFrom'];
    final to = row['yearTo'];
    if (from == null) return '';
    return '  $from–${to ?? 'н.в.'}';
  }
}

/// Поле «Машина»: открывает [VehiclePickerPage].
class VehicleReferenceFields extends StatefulWidget {
  const VehicleReferenceFields({
    super.key,
    this.initialMake,
    this.initialModel,
    this.initialGeneration,
    required this.onChanged,
  });

  final String? initialMake;
  final String? initialModel;
  final String? initialGeneration;
  final ValueChanged<VehicleSelection?> onChanged;

  @override
  State<VehicleReferenceFields> createState() => _VehicleReferenceFieldsState();
}

class _VehicleReferenceFieldsState extends State<VehicleReferenceFields> {
  VehicleSelection? _value;

  @override
  void initState() {
    super.initState();
    final make = widget.initialMake?.trim() ?? '';
    final model = widget.initialModel?.trim() ?? '';
    if (make.isNotEmpty && model.isNotEmpty) {
      _value = VehicleSelection(
        makeId: 0,
        make: make,
        modelId: 0,
        model: model,
        generation: widget.initialGeneration,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<VehicleSelection>(
      initialValue: _value,
      validator: (value) => value == null || value.model.trim().isEmpty
          ? 'Выберите машину'
          : null,
      builder: (state) {
        final text = state.value?.label;
        return InkWell(
          onTap: () async {
            final picked = await VehiclePickerPage.open(context);
            if (picked == null || !mounted) return;
            setState(() => _value = picked);
            state.didChange(picked);
            widget.onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Машина *',
              border: const OutlineInputBorder(),
              errorText: state.errorText,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                (text == null || text.isEmpty)
                    ? 'Марка, модель, поколение'
                    : text,
                style: TextStyle(
                  color: text == null || text.isEmpty
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
