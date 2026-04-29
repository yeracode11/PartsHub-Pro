import 'package:dio/dio.dart';

import '../../../core/network/api_helpers.dart';
import 'models/subscription_entity.dart';

class SubscriptionsApi {
  SubscriptionsApi(this._dio);

  final Dio _dio;

  Future<List<SubscriptionEntity>> listSubscriptions() {
    return guardApi(() async {
      final res = await _dio.get<dynamic>('/subscriptions');
      return _parseList(res.data);
    });
  }

  Future<SubscriptionEntity> patchSubscription(String id, Map<String, dynamic> body) {
    return guardApi(() async {
      final res = await _dio.patch<Map<String, dynamic>>('/subscriptions/$id', data: body);
      return SubscriptionEntity.fromJson(res.data ?? {});
    });
  }

  List<SubscriptionEntity> _parseList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => SubscriptionEntity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final list = raw['data'] ?? raw['items'];
      if (list is List) {
        return list
            .map((e) => SubscriptionEntity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }
}
