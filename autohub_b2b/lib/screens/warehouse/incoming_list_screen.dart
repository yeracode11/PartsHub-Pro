import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/incoming_api_service.dart';
import 'package:autohub_b2b/screens/warehouse/incoming_doc_screen.dart';

class IncomingListScreen extends StatefulWidget {
  const IncomingListScreen({super.key});

  @override
  State<IncomingListScreen> createState() => _IncomingListScreenState();
}

class _IncomingListScreenState extends State<IncomingListScreen> {
  final IncomingApiService _apiService = IncomingApiService(ApiClient());
  List<IncomingDocModel> _documents = [];
  bool _isLoading = true;
  String? _error;
  IncomingDocStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final docs = await _apiService.getDocuments(
        status: _filterStatus?.name,
      );
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Приходные накладные'),
        elevation: 0,
        actions: [
          // Фильтр по статусу
          PopupMenuButton<IncomingDocStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _filterStatus = status;
              });
              _loadDocuments();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Все'),
              ),
              const PopupMenuItem(
                value: IncomingDocStatus.draft,
                child: Text('Черновики'),
              ),
              const PopupMenuItem(
                value: IncomingDocStatus.done,
                child: Text('Проведенные'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const IncomingDocScreen(),
                ),
              );
              if (result == true) {
                _loadDocuments();
              }
            },
            tooltip: 'Создать накладную',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDocuments,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _documents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет приходных накладных',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const IncomingDocScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadDocuments();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Создать накладную'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDocuments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          return _buildDocumentCard(doc);
                        },
                      ),
                    ),
    );
  }

  Widget _buildDocumentCard(IncomingDocModel doc) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final numberFormat = NumberFormat('#,###', 'ru_RU');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => IncomingDocScreen(docId: doc.id),
            ),
          );
          if (result == true) {
            _loadDocuments();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.docNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(doc.date),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(doc.status),
                ],
              ),
              const SizedBox(height: 12),
              if (doc.supplierName != null) ...[
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.supplierName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Сумма: ${numberFormat.format(doc.totalAmount)} ₸',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (doc.items != null && doc.items!.isNotEmpty)
                    Text(
                      '${doc.items!.length} позиций',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(IncomingDocStatus status) {
    Color color;
    switch (status) {
      case IncomingDocStatus.draft:
        color = Colors.orange;
        break;
      case IncomingDocStatus.done:
        color = Colors.green;
        break;
      case IncomingDocStatus.cancelled:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

