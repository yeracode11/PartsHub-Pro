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
  });

  final int makeId;
  final String make;
  final int modelId;
  final String model;
  final int? generationId;
  final String? generation;
}

/// Марка → модель → поколение из локального справочника.
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
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _makes = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _generations = [];
  int? _makeId;
  int? _modelId;
  int? _generationId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMakes();
  }

  Future<void> _loadMakes() async {
    try {
      final response = await _dio.get('/api/vehicles/makes');
      final items = List<Map<String, dynamic>>.from(
        (response.data['items'] as List?) ?? [],
      );
      if (!mounted) return;
      final match = _named(items, widget.initialMake);
      setState(() {
        _makes = items;
        _loading = false;
        _error = items.isEmpty ? 'Справочник пуст' : null;
        _makeId = match?['id'] as int?;
      });
      if (_makeId != null) await _loadModels(_makeId!, keep: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingApiMessage(e);
      });
    }
  }

  Future<void> _loadModels(int makeId, {bool keep = false}) async {
    setState(() {
      _models = [];
      _generations = [];
      if (!keep) {
        _modelId = null;
        _generationId = null;
      }
    });
    final response = await _dio.get('/api/vehicles/makes/$makeId/models');
    if (!mounted) return;
    final items = List<Map<String, dynamic>>.from(
      (response.data['items'] as List?) ?? [],
    );
    final match = keep ? _named(items, widget.initialModel) : null;
    setState(() {
      _models = items;
      _modelId = match?['id'] as int?;
    });
    if (_modelId != null) {
      await _loadGenerations(_modelId!, keep: keep);
    } else {
      _emit();
    }
  }

  Future<void> _loadGenerations(int modelId, {bool keep = false}) async {
    final response = await _dio.get(
      '/api/vehicles/models/$modelId/generations',
    );
    if (!mounted) return;
    final items = List<Map<String, dynamic>>.from(
      (response.data['items'] as List?) ?? [],
    );
    final match = keep ? _named(items, widget.initialGeneration) : null;
    setState(() {
      _generations = items;
      _generationId = match?['id'] as int?;
    });
    _emit();
  }

  Map<String, dynamic>? _named(List<Map<String, dynamic>> rows, String? name) {
    final want = name?.trim().toLowerCase();
    if (want == null || want.isEmpty) return null;
    for (final row in rows) {
      if ((row['name'] as String?)?.toLowerCase() == want) return row;
    }
    return null;
  }

  Map<String, dynamic>? _byId(List<Map<String, dynamic>> rows, int? id) {
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  void _emit() {
    final make = _byId(_makes, _makeId);
    final model = _byId(_models, _modelId);
    if (make == null || model == null) {
      widget.onChanged(null);
      return;
    }
    final generation = _byId(_generations, _generationId);
    widget.onChanged(
      VehicleSelection(
        makeId: make['id'] as int,
        make: make['name'] as String,
        modelId: model['id'] as int,
        model: model['name'] as String,
        generationId: generation?['id'] as int?,
        generation: generation?['name'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text(_error!, style: TextStyle(color: AppTheme.errorColor));
    }
    return Column(
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('make-${_makes.length}-$_makeId'),
          initialValue: _makeId,
          decoration: const InputDecoration(labelText: 'Марка *'),
          items: [
            for (final row in _makes)
              DropdownMenuItem(
                value: row['id'] as int,
                child: Text(row['name'] as String),
              ),
          ],
          onChanged: (value) async {
            setState(() => _makeId = value);
            if (value != null) await _loadModels(value);
          },
          validator: (value) => value == null ? 'Выберите марку' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('model-$_makeId-${_models.length}-$_modelId'),
          initialValue: _modelId,
          decoration: const InputDecoration(labelText: 'Модель *'),
          items: [
            for (final row in _models)
              DropdownMenuItem(
                value: row['id'] as int,
                child: Text(row['name'] as String),
              ),
          ],
          onChanged: _makeId == null
              ? null
              : (value) async {
                  setState(() => _modelId = value);
                  if (value != null) await _loadGenerations(value);
                },
          validator: (value) => value == null ? 'Выберите модель' : null,
        ),
        if (_generations.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('generation-$_modelId-${_generations.length}'),
            initialValue: _generationId,
            decoration: const InputDecoration(labelText: 'Поколение'),
            items: [
              for (final row in _generations)
                DropdownMenuItem(
                  value: row['id'] as int,
                  child: Text(row['name'] as String),
                ),
            ],
            onChanged: (value) {
              setState(() => _generationId = value);
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
