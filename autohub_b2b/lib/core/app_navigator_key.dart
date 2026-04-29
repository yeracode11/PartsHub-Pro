import 'package:flutter/material.dart';

/// Корневой [Navigator] для [MaterialApp] — нужен для сценария «истекла сессия»
/// из [Dio] без [BuildContext] с экрана.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');
