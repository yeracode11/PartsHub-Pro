import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/blocs/warehouse/warehouse_bloc.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_bloc.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/screens/auth/login_screen.dart';
import 'package:autohub_b2b/screens/dashboard/dashboard_screen.dart';
import 'package:autohub_b2b/screens/warehouse/warehouse_screen.dart';
import 'package:autohub_b2b/screens/sales/sales_screen.dart';
import 'package:autohub_b2b/screens/crm/crm_screen.dart';
import 'package:autohub_b2b/screens/analytics/analytics_screen.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_screen.dart';
import 'package:autohub_b2b/screens/vehicles/vehicles_screen.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Инициализация базы данных
  final database = AppDatabase();

  runApp(AutoHubApp(database: database));
}

class AutoHubApp extends StatelessWidget {
  final AppDatabase database;

  const AutoHubApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc()..add(AuthCheckRequested()),
        ),
        BlocProvider(
          create: (context) => WarehouseBloc(database: database),
        ),
        BlocProvider(
          create: (context) => DashboardBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'AutoHub B2B',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              print('🎯 App BlocListener: state changed to ${state.runtimeType}');
            },
            child: child!,
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

// Обертка для управления навигацией на основе состояния авторизации
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        print('🏠 AuthWrapper BlocBuilder: Current state = ${state.runtimeType}');
        
        // Загрузка
        if (state is AuthInitial || state is AuthLoading) {
          print('🏠 AuthWrapper: Showing loading screen');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Авторизован - показываем главный экран
        if (state is AuthAuthenticated) {
          print('🏠 AuthWrapper: User authenticated, showing MainScreen');
          return const MainScreen();
        }
        
        // Не авторизован или ошибка - показываем экран входа
        print('🏠 AuthWrapper: Showing LoginScreen');
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const WarehouseScreen(),
    const SalesScreen(),
    const CrmScreen(),
    const VehiclesScreen(),
    const AnalyticsScreen(),
    const WhatsAppScreen(),
    const PlaceholderScreen(title: 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Боковое меню
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                right: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Логотип
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.car_repair,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AutoHub',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'B2B Platform',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Навигационные элементы
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildNavItem(
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard,
                        label: 'Дашборд',
                        index: 0,
                      ),
                      _buildNavItem(
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2,
                        label: 'Склад',
                        index: 1,
                      ),
                      _buildNavItem(
                        icon: Icons.shopping_bag_outlined,
                        selectedIcon: Icons.shopping_bag,
                        label: 'Продажи',
                        index: 2,
                      ),
                      _buildNavItem(
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        label: 'CRM',
                        index: 3,
                      ),
                      _buildNavItem(
                        icon: Icons.directions_car_outlined,
                        selectedIcon: Icons.directions_car,
                        label: 'Автомобили',
                        index: 4,
                      ),
                      _buildNavItem(
                        icon: Icons.analytics_outlined,
                        selectedIcon: Icons.analytics,
                        label: 'Аналитика',
                        index: 5,
                      ),
                      _buildNavItem(
                        icon: Icons.message_outlined,
                        selectedIcon: Icons.message,
                        label: 'WhatsApp',
                        index: 6,
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildNavItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: 'Настройки',
                        index: 7,
                      ),
                    ],
                  ),
                ),
                
                    // Нижняя часть - профиль пользователя
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          String userName = 'Пользователь';
                          String userEmail = '';
                          
                          if (state is AuthAuthenticated) {
                            userName = state.user.name.isNotEmpty 
                                ? state.user.name 
                                : state.user.email.split('@')[0];
                            userEmail = state.user.email;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        userEmail,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
          
          // Основной контент
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction_outlined,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Раздел "$title"',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Этот раздел находится в разработке.\nСкоро он будет доступен!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Скоро',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
