import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/services/service_details_screen.dart';
import '../screens/services/book_appointment_screen.dart';
import '../models/service_model.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/vehicle/vehicle_health_screen.dart';
import '../screens/vehicle/add_vehicle_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_details_screen.dart';
import '../screens/cart/cart_screen.dart';

class AppRouter {
  static GoRouter createRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Авторизация
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Главный экран с Bottom Navigation
      ShellRoute(
        builder: (context, state, child) {
          return HomeScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/services',
            builder: (context, state) => const ServicesScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
        ],
      ),
      
      // Детальные экраны
      GoRoute(
        path: '/vehicle-health',
        builder: (context, state) => const VehicleHealthScreen(),
      ),
      GoRoute(
        path: '/add-vehicle',
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/order/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderDetailsScreen(orderId: orderId);
        },
      ),
      
      // Сервисы
      GoRoute(
        path: '/service/:serviceId',
        builder: (context, state) {
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
        builder: (context, state) {
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
