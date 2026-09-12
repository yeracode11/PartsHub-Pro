import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_branding.dart';
import 'config/environment.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/api_client.dart';
import 'services/marketplace_api_service.dart';
import 'services/vehicles_api_service.dart';
import 'services/services_api_service.dart';
import 'services/auth_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/marketplace/marketplace_bloc.dart';
import 'blocs/services/services_bloc.dart';
import 'blocs/vehicle/vehicle_bloc.dart';
import 'blocs/vehicle/vehicle_event.dart';
import 'blocs/cart/cart_bloc.dart';
import 'blocs/cart/cart_event.dart';
import 'utils/formatters.dart';

Future<String> _getInitialRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  return onboardingCompleted ? '/login' : '/onboarding';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  Formatters.ensureInitialized();

  final initialRoute = await _getInitialRoute();
  runApp(AutoHubB2CApp(initialRoute: initialRoute));
}

class AutoHubB2CApp extends StatefulWidget {
  final String initialRoute;

  const AutoHubB2CApp({super.key, required this.initialRoute});

  @override
  State<AutoHubB2CApp> createState() => _AutoHubB2CAppState();
}

class _AutoHubB2CAppState extends State<AutoHubB2CApp> {
  late final ApiClient _apiClient;
  late final AuthBloc _authBloc;
  late final VehicleBloc _vehicleBloc;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authBloc = AuthBloc(authService: AuthService(_apiClient));
    _vehicleBloc = VehicleBloc(
      apiService: VehiclesApiService(_apiClient),
    );
    _authBloc.add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    _vehicleBloc.close();
    super.dispose();
  }

  void _reloadVehiclesIfAuthenticated(AuthState state) {
    if (state is AuthAuthenticated) {
      _vehicleBloc.add(VehicleLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceApi = MarketplaceApiService(_apiClient);
    final vehiclesApi = VehiclesApiService(_apiClient);
    final servicesApi = ServicesApiService(_apiClient);

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(
          create: (_) => MarketplaceBloc(apiService: marketplaceApi),
        ),
        BlocProvider(
          create: (_) => ServicesBloc(apiService: servicesApi),
        ),
        BlocProvider.value(value: _vehicleBloc),
        BlocProvider(
          create: (_) => CartBloc()..add(CartLoadRequested()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (_, state) => _reloadVehiclesIfAuthenticated(state),
        child: MaterialApp.router(
          title: AppBranding.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRouter.createRouter(
            initialLocation: widget.initialRoute,
            authBloc: _authBloc,
          ),
        ),
      ),
    );
  }
}
