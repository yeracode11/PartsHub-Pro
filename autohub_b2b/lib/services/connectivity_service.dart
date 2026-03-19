import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _pluginAvailable = false;

  ConnectivityService._internal();

  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(results);
      _pluginAvailable = true;

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _setOnline(_hasConnection(results));
      });
    } catch (e) {
      debugPrint('[Connectivity] Plugin unavailable, using Dio-based detection: $e');
      _pluginAvailable = false;
      _isOnline = true;
    }
  }

  /// Called by ApiClient interceptor when a request succeeds.
  void reportOnline() {
    if (!_pluginAvailable) {
      _setOnline(true);
    }
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
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
