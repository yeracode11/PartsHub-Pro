import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'core/injection/app_dependencies.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env/app.env');
  AppConfig.resolveAfterEnvLoaded();
  final deps = AppDependencies.bootstrap();
  runApp(AutoHubAdminApp(deps: deps));
}
