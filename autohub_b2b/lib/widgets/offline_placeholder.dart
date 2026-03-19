import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/core/theme.dart';

/// Returns true if the exception is a network/connectivity error.
bool isNetworkError(Object e) {
  if (e is DioException) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
  if (e is Exception && e.toString().contains('SocketException')) return true;
  if (e is Exception && e.toString().contains('Connection failed')) return true;
  return false;
}

/// Friendly offline placeholder shown when a screen can't load data.
class OfflinePlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflinePlaceholder({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Нет подключения к интернету',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Данные этого раздела пока недоступны офлайн.\nПодключитесь к сети и попробуйте снова.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
