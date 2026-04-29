import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'core/injection/app_dependencies.dart';
import 'core/logging/app_logger.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env/app.env');
  AppConfig.resolveAfterEnvLoaded();
  AppLogger.info(
    'Старт: API_BASE_URL=${AppConfig.apiBaseUrl} · Dio.baseUrl=${AppConfig.dioBaseUrl} (как в autohub_b2b ApiClient)',
  );
  final deps = AppDependencies.bootstrap();
  runApp(AutoHubAdminApp(deps: deps));
}
