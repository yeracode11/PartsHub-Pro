import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Справочник работ организации: название, нормо-часы и ставка за нормо-час.
class WorkCatalogScreen extends StatefulWidget {
  const WorkCatalogScreen({super.key});

  @override
  State<WorkCatalogScreen> createState() => _WorkCatalogScreenState();
}

class _WorkCatalogScreenState extends State<WorkCatalogScreen> {
  final _dio = ApiClient().dio;
  List<WorkCatalogModel> _works = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/api/works');
      final list = (response.data as List)
          .map((item) => WorkCatalogModel.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _works = list;
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

  Future<void> _edit([WorkCatalogModel? work]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WorkCatalogDialog(dio: _dio, work: work),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(WorkCatalogModel work) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить работу?'),
        content: Text(work.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.delete('/api/works/${work.id}');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка удаления'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,###', 'ru_RU');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник работ'),
        actions: [
          IconButton(
            tooltip: 'Добавить работу',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _works.isEmpty
                  ? const Center(child: Text('Работ пока нет. Добавьте первую.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _works.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final work = _works[index];
                        return ListTile(
                          title: Text(work.name),
                          subtitle: Text(
                            '${work.normHours} н/ч × ${money.format(work.pricePerHour)} ₸',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${money.format(work.price)} ₸',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _edit(work);
                                  if (value == 'delete') _delete(work);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Изменить')),
                                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _edit(work),
                        );
                      },
                    ),
    );
  }
}

class _WorkCatalogDialog extends StatefulWidget {
  final dynamic dio;
  final WorkCatalogModel? work;

  const _WorkCatalogDialog({required this.dio, this.work});

  @override
  State<_WorkCatalogDialog> createState() => _WorkCatalogDialogState();
}

class _WorkCatalogDialogState extends State<_WorkCatalogDialog> {
  late final TextEditingController _name;
  late final TextEditingController _hours;
  late final TextEditingController _rate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final work = widget.work;
    _name = TextEditingController(text: work?.name ?? '');
    _hours = TextEditingController(text: '${work?.normHours ?? 1}');
    _rate = TextEditingController(text: '${work?.pricePerHour ?? 0}');
  }

  @override
  void dispose() {
    _name.dispose();
    _hours.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final hours = double.tryParse(_hours.text.replaceAll(',', '.'));
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    if (name.isEmpty || hours == null || hours <= 0 || rate == null || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте название, нормо-часы и ставку')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {'name': name, 'normHours': hours, 'pricePerHour': rate};
      if (widget.work == null) {
        await widget.dio.post('/api/works', data: data);
      } else {
        await widget.dio.put('/api/works/${widget.work!.id}', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка сохранения'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.work == null ? 'Новая работа' : 'Работа'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hours,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Нормо-часы',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ставка, ₸/н·ч',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
