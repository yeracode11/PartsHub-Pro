import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

const _channels = <String, String>{
  'catalog': 'Каталог',
  'kolesa': 'Kolesa',
  'olx': 'OLX',
  'whatsapp': 'WhatsApp',
  'telegram': 'Telegram',
};

/// Публикация товара. Склад сам площадки не вызывает.
class ItemListingsSection extends StatefulWidget {
  const ItemListingsSection({super.key, required this.itemId});

  final int itemId;

  @override
  State<ItemListingsSection> createState() => _ItemListingsSectionState();
}

class _ItemListingsSectionState extends State<ItemListingsSection> {
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get(
        '/api/listings',
        queryParameters: {'itemId': widget.itemId},
      );
      if (!mounted) return;
      final data = response.data;
      setState(() {
        _rows = data is List
            ? data
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingApiMessage(e);
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _row(String channel) {
    for (final row in _rows) {
      if (row['channel'] == channel && row['status'] != 'archived') return row;
    }
    return null;
  }

  bool _on(Map<String, dynamic>? row) {
    final status = row?['status'];
    return status == 'published' || status == 'needs_sync';
  }

  Future<void> _toggle(String channel, bool value) async {
    final current = _row(channel);
    try {
      if (!value && current != null) {
        await _dio.post('/api/listings/${current['id']}/pause');
      } else if (value && current != null) {
        await _dio.post('/api/listings/${current['id']}/publish');
      } else if (value) {
        await _dio.post(
          '/api/listings',
          data: {'itemId': widget.itemId, 'channel': channel, 'publish': true},
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Объявления',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Остаток уходит на площадку после движения склада',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: AppTheme.errorColor))
            else
              ..._channels.entries.map((entry) {
                final row = _row(entry.key);
                final waiting = row?['status'] == 'needs_sync';
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  subtitle: waiting
                      ? Text(
                          row?['lastSyncError']?.toString() ?? 'Ждёт отправки',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      : null,
                  value: _on(row),
                  onChanged: (value) => _toggle(entry.key, value),
                );
              }),
          ],
        ),
      ),
    );
  }
}
