import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/api_client.dart';
import 'services/marketplace_api_service.dart';
import 'services/orders_api_service.dart';
import 'services/vehicles_api_service.dart';
import 'services/services_api_service.dart';
import 'services/auth_service.dart';
import 'services/dashboard_api_service.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_event.dart';
import 'blocs/theme/theme_state.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/marketplace/marketplace_bloc.dart';
import 'blocs/services/services_bloc.dart';
import 'blocs/vehicle/vehicle_bloc.dart';
import 'blocs/cart/cart_bloc.dart';
import 'blocs/cart/cart_event.dart';

Future<String> _getInitialRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  return onboardingCompleted ? '/login' : '/onboarding';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Определяем начальный роут
  final initialRoute = await _getInitialRoute();

  runApp(AutoHubB2CApp(initialRoute: initialRoute));
}

class AutoHubB2CApp extends StatelessWidget {
  final String initialRoute;

  const AutoHubB2CApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // Инициализация API сервисов
    final apiClient = ApiClient();
    final marketplaceApiService = MarketplaceApiService(apiClient);
    final ordersApiService = OrdersApiService(apiClient);
    final vehiclesApiService = VehiclesApiService(apiClient);
    final servicesApiService = ServicesApiService(apiClient);
    final authService = AuthService(apiClient);
    final dashboardApiService = DashboardApiService(apiClient);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ThemeBloc()..add(ThemeLoadRequested()),
        ),
        BlocProvider(
          create: (context) => AuthBloc(),
        ),
        BlocProvider(
          create: (context) => MarketplaceBloc(apiService: marketplaceApiService),
        ),
        BlocProvider(
          create: (context) => ServicesBloc(apiService: servicesApiService),
        ),
        BlocProvider(
          create: (context) => VehicleBloc(),
        ),
        BlocProvider(
          create: (context) => CartBloc()..add(CartLoadRequested()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Auto+R',
            debugShowCheckedModeBanner: false,
            theme: themeState.themeData,
            routerConfig: AppRouter.createRouter(initialRoute),
          );
        },
      ),
    );
  }
}