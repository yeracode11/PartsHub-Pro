import 'package:dio/dio.dart';

import '../../../core/network/api_helpers.dart';
import 'models/user_entity.dart';

class UsersApi {
  UsersApi(this._dio);

  final Dio _dio;

  Future<UsersPageResult> listUsers({
    required int page,
    required int pageSize,
    String? search,
  }) {
    return guardApi(() async {
      final res = await _dio.get<dynamic>(
        '/users',
        queryParameters: {
          'page': page,
          'limit': pageSize,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      return _parsePage(res.data, page: page, pageSize: pageSize);
    });
  }

  UsersPageResult _parsePage(dynamic raw, {required int page, required int pageSize}) {
    if (raw is List) {
      final items = raw.map((e) => UserEntity.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return UsersPageResult(items: items, total: items.length, page: 1, pageSize: items.length);
    }

    if (raw is Map<String, dynamic>) {
      final listRaw = raw['data'] ?? raw['items'] ?? raw['results'];
      final totalRaw = raw['total'] ?? raw['count'];
      final items = <UserEntity>[];
      if (listRaw is List) {
        for (final e in listRaw) {
          if (e is Map<String, dynamic>) {
            items.add(UserEntity.fromJson(e));
          }
        }
      }
      final total = totalRaw is num ? totalRaw.toInt() : items.length;
      return UsersPageResult(items: items, total: total, page: page, pageSize: pageSize);
    }

    return UsersPageResult(items: const [], total: 0, page: page, pageSize: pageSize);
  }

  Future<UserEntity> getUser(String id) {
    return guardApi(() async {
      final res = await _dio.get<Map<String, dynamic>>('/users/$id');
      return UserEntity.fromJson(res.data ?? {});
    });
  }

  Future<UserEntity> createUser(Map<String, dynamic> body) {
    return guardApi(() async {
      final res = await _dio.post<Map<String, dynamic>>('/users', data: body);
      return UserEntity.fromJson(res.data ?? {});
    });
  }

  Future<UserEntity> updateUser(String id, Map<String, dynamic> body) {
    return guardApi(() async {
      final res = await _dio.patch<Map<String, dynamic>>('/users/$id', data: body);
      return UserEntity.fromJson(res.data ?? {});
    });
  }

  Future<void> deleteUser(String id) {
    return guardApi(() async {
      await _dio.delete<void>('/users/$id');
    });
  }
}
