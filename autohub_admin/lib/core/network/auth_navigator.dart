import 'package:flutter/material.dart';

/// Global hooks used by [Dio] interceptors — wired from [MaterialApp] bootstrap.
class AuthNavigator {
  AuthNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Clears session and shows login (401).
  static void Function()? onUnauthorized;

  /// Full-screen or routed forbidden UX after an API 403 while authenticated.
  static void Function(String? message)? onForbidden;
}
