import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/warehouse_service.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/widgets/barcode_scanner_page.dart';

/// Пересчёт склада: факт сравнивается с остатком в момент утверждения.
class StocktakingScreen extends StatefulWidget {
  const StocktakingScreen({super.key});

  @override
  State<StocktakingScreen> createState() => _StocktakingScreenState();
}

class _StocktakingScreenState extends State<StocktakingScreen> {
  final _dio = ApiClient().dio;
  final _code = TextEditingController();
  final _qty = TextEditingController();

  List<Map<String, String>> _warehouses = [];
  String? _warehouseId;
  Map<String, dynamic>? _doc;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _code.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await WarehouseService().getWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = list.map((w) => {'id': w.id, 'name': w.name}).toList();
        _warehouseId = _warehouses.isEmpty ? null : _warehouses.first['id'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingApiMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    final warehouseId = _warehouseId;
    if (warehouseId == null) return;
    setState(() => _busy = true);
    try {
      final response = await _dio.post(
        '/api/stocktakings',
        data: {'warehouseId': warehouseId},
      );
      if (!mounted) return;
      setState(() {
        _doc = Map<String, dynamic>.from(response.data as Map);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerPage.scan(context, title: 'Товар');
    if (code == null || !mounted) return;
    setState(() => _code.text = code);
  }

  Future<void> _count() async {
    final doc = _doc;
    final counted = int.tryParse(_qty.text.trim());
    if (doc == null || counted == null || counted < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фактическое количество')),
      );
      return;
    }
    if (_code.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите код товара')));
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await _dio.post(
        '/api/stocktakings/${doc['id']}/lines',
        data: {'code': _code.text.trim(), 'countedQuantity': counted},
      );
      if (!mounted) return;
      setState(() {
        _doc = Map<String, dynamic>.from(response.data as Map);
        _code.clear();
        _qty.clear();
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }

  Future<void> _approve() async {
    final doc = _doc;
    if (doc == null) return;
    setState(() => _busy = true);
    try {
      final response = await _dio.post(
        '/api/stocktakings/${doc['id']}/approve',
      );
      if (!mounted) return;
      setState(() {
        _doc = Map<String, dynamic>.from(response.data as Map);
        _busy = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Остатки обновлены')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = (_doc?['lines'] as List?) ?? const [];
    final draft = _doc?['status'] == 'draft';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Инвентаризация'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: AppTheme.errorColor),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_doc == null) ...[
                  if (_warehouses.isEmpty)
                    const Text('Нет складов')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(labelText: 'Склад'),
                      items: _warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'],
                              child: Text(w['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _warehouseId = value),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _warehouseId == null ? null : _start,
                    child: const Text('Начать'),
                  ),
                ] else ...[
                  Text(
                    draft
                        ? 'Утверждение сравнивает факт с остатком на этот момент.'
                        : 'Инвентаризация закрыта',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  if (draft) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Штрихкод, OEM или артикул',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Факт'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _busy ? null : _scan,
                          child: const Text('Сканер'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _busy ? null : _count,
                          child: const Text('Записать'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...lines.map((raw) {
                    final line = raw as Map;
                    final item = line['item'] as Map?;
                    final counted = line['countedQuantity'];
                    final expected = line['expectedQuantity'];
                    final difference = line['difference'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item?['name']?.toString() ?? 'Товар'),
                      subtitle: Text(
                        counted == null
                            ? 'В системе $expected'
                            : 'В системе $expected · факт $counted · ${difference ?? 0}',
                      ),
                    );
                  }),
                  if (draft && canSeeFinance(context)) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _approve,
                      child: const Text('Утвердить'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
