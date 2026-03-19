import 'dart:async';
import 'package:flutter/material.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/sync_service.dart';
import 'package:autohub_b2b/services/service_locator.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _sync = ServiceLocator().syncService;

  late bool _isOnline;
  bool _isSyncing = false;
  bool _justReconnected = false;

  StreamSubscription<bool>? _connSub;
  StreamSubscription<SyncState>? _syncSub;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivity.isOnline;

    _connSub = _connectivity.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
        if (online) _justReconnected = true;
      });
      if (online) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _justReconnected = false);
        });
      }
    });

    _syncSub = _sync.onSyncStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isSyncing = state == SyncState.syncing);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline && !_isSyncing && !_justReconnected) {
      return const SizedBox.shrink();
    }

    final Color bgColor;
    final String text;
    final IconData icon;

    if (!_isOnline) {
      bgColor = Colors.grey.shade700;
      text = 'Нет подключения — офлайн-режим';
      icon = Icons.cloud_off;
    } else if (_isSyncing) {
      bgColor = Colors.blue.shade600;
      text = 'Синхронизация данных...';
      icon = Icons.sync;
    } else {
      bgColor = Colors.green.shade600;
      text = 'Подключение восстановлено';
      icon = Icons.cloud_done;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
