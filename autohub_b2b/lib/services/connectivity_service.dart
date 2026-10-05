import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/config/environment.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService._internal();

  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _handleResults(results);

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _handleResults(results);
      });
    } catch (e) {
      debugPrint('[Connectivity] Plugin unavailable, using Dio-based detection: $e');
      _isOnline = true;
    }
  }

  Future<void> _handleResults(List<ConnectivityResult> results) async {
    if (_hasConnection(results)) {
      _setOnline(true);
      return;
    }

    // На симуляторе iOS / некоторых сетевых мостах connectivity_plus возвращает [none],
    // хотя реальный интернет и сервер доступны. Проверяем фактическую доступность перед объявлением офлайна.
    final reachable = await _verifyReachability();
    _setOnline(reachable);
  }

  Future<bool> _verifyReachability() async {
    if (kIsWeb) return true;
    try {
      final host = Uri.tryParse(Environment.apiBaseUrl)?.host ?? '108.174.78.106';
      final res = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
      return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final res = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
        return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Called by ApiClient interceptor when a request succeeds.
  void reportOnline() {
    _setOnline(true);
  }

  /// Called by ApiClient interceptor on connection/timeout errors.
  void reportOffline() {
    _setOnline(false);
  }

  void _setOnline(bool online) {
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
      debugPrint('[Connectivity] ${_isOnline ? "ONLINE" : "OFFLINE"}');
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
