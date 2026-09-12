import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../screens/shell/app_shell.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/garage/garage_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/services/service_details_screen.dart';
import '../screens/services/book_appointment_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_details_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/vehicle/vehicle_detail_screen.dart';
import '../screens/vehicle/add_vehicle_screen.dart';
import '../screens/marketplace/product_details_screen.dart';
import '../models/service_model.dart';
import '../models/product_model.dart';

class AppRouter {
  static GoRouter createRouter({
    required String initialLocation,
    required AuthBloc authBloc,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: _AuthRefresh(authBloc),
      redirect: (context, state) {
        final authState = authBloc.state;
        final path = state.matchedLocation;
        final isAuthRoute = path == '/login' || path == '/register';
        final isOnboarding = path == '/onboarding';

        if (authState is AuthInitial || authState is AuthLoading) {
          return null;
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          if (isOnboarding || isAuthRoute) return null;
          return '/login';
        }

        if (authState is AuthAuthenticated) {
          if (isOnboarding || isAuthRoute) return '/garage';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/garage',
              builder: (_, __) => const GarageScreen(),
            ),
            GoRoute(
              path: '/parts',
              builder: (context, state) {
                final category = state.uri.queryParameters['category'];
                return MarketplaceScreen(initialCategory: category);
              },
            ),
            GoRoute(
              path: '/services',
              builder: (_, __) => const ServicesScreen(),
            ),
            GoRoute(
              path: '/orders',
              builder: (_, __) => const OrdersScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/cart',
          builder: (_, __) => const CartScreen(),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, state) {
            final product = state.extra as Product?;
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ProductDetailsScreen(product: product, productId: id);
          },
        ),
        GoRoute(
          path: '/vehicle/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return VehicleDetailScreen(vehicleId: id);
          },
        ),
        GoRoute(
          path: '/add-vehicle',
          builder: (_, __) => const AddVehicleScreen(),
        ),
        GoRoute(
          path: '/order/:orderId',
          builder: (_, state) {
            final orderId = state.pathParameters['orderId']!;
            return OrderDetailsScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/service/:serviceId',
          builder: (_, state) {
            final service = state.extra as AutoService?;
            if (service == null) {
              return const Scaffold(
                body: Center(child: Text('Сервис не найден')),
              );
            }
            return ServiceDetailsScreen(service: service);
          },
        ),
        GoRoute(
          path: '/book-appointment/:serviceId',
          builder: (_, state) {
            final service = state.extra as AutoService?;
            if (service == null) {
              return const Scaffold(
                body: Center(child: Text('Сервис не найден')),
              );
            }
            return BookAppointmentScreen(service: service);
          },
        ),
      ],
    );
  }
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc bloc;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
