import 'package:dio/dio.dart';

import '../../../core/network/api_helpers.dart';
import 'models/transaction_entity.dart';

class TransactionsApi {
  TransactionsApi(this._dio);

  final Dio _dio;

  Future<List<TransactionEntity>> listTransactions({
    DateTime? from,
    DateTime? to,
    String? userId,
  }) {
    return guardApi(() async {
      final res = await _dio.get<dynamic>(
        '/transactions',
        queryParameters: {
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
          if (userId != null && userId.isNotEmpty) 'userId': userId,
        },
      );
      return _parseList(res.data);
    });
  }

  List<TransactionEntity> _parseList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => TransactionEntity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final list = raw['data'] ?? raw['items'];
      if (list is List) {
        return list
            .map((e) => TransactionEntity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }
}
