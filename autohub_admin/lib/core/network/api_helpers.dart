import 'package:dio/dio.dart';

import '../error/app_exception.dart';

Future<T> guardApi<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    throw AppException(_dioMessage(e), statusCode: e.response?.statusCode);
  }
}

String _dioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    final m = data['message'];
    if (m is String) return m;
    if (m is List && m.isNotEmpty) return m.first.toString();
  }
  if (e.message != null && e.message!.isNotEmpty) return e.message!;
  return 'Network error';
}
