import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Переход с главной на другой раздел с возможностью вернуться назад.
void navigateFromGarage(BuildContext context, String path) {
  if (path == '/garage') {
    context.go('/garage');
    return;
  }

  final uri = Uri.parse(path);
  final params = Map<String, String>.from(uri.queryParameters);
  params['from'] = 'garage';

  context.go(uri.replace(queryParameters: params).toString());
}

bool shouldShowGarageBack(BuildContext context) {
  return GoRouterState.of(context).uri.queryParameters['from'] == 'garage';
}

void backFromGarageContext(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/garage');
  }
}
