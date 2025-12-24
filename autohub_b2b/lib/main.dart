import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/blocs/warehouse/warehouse_bloc.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_bloc.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/screens/auth/login_screen.dart';
import 'package:autohub_b2b/screens/dashboard/dashboard_screen.dart';
import 'package:autohub_b2b/screens/warehouse/warehouse_screen.dart';
import 'package:autohub_b2b/screens/warehouse/incoming_list_screen.dart';
import 'package:autohub_b2b/screens/warehouse/warehouse_location_screen.dart';
import 'package:autohub_b2b/screens/warehouse/warehouses_screen.dart';
import 'package:autohub_b2b/screens/warehouse/warehouse_transfers_screen.dart';
import 'package:autohub_b2b/screens/warehouse/find_part_screen.dart';
import 'package:autohub_b2b/screens/sales/sales_screen.dart';
import 'package:autohub_b2b/screens/crm/crm_screen.dart';
import 'package:autohub_b2b/screens/analytics/analytics_screen.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_screen.dart';
import 'package:autohub_b2b/screens/vehicles/vehicles_screen.dart';
import 'package:autohub_b2b/screens/profile/profile_screen.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/test_print_simple.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
        title: 'Auto+ Pro',
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
  bool _warehouseMenuExpanded = false;
  int? _warehouseSubMenuIndex; // null = закрыто, 0 = Товары, 1 = Оприходование, 2 = Расположение, 3 = Склады, 4 = Перемещения
  String? _userRole; // Роль текущего пользователя

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
  void initState() {
    super.initState();
    _loadUserRole();
  }

  // Загрузка роли пользователя
  Future<void> _loadUserRole() async {
    final userData = await SecureStorageService().getUserData();
    if (mounted && userData != null) {
      setState(() {
        _userRole = userData['role'] as String?;
        
        // Для кладовщика по умолчанию открываем Склад
        if (_userRole == 'UserRole.storekeeper' && _selectedIndex == 0) {
          _selectedIndex = 1; // Склад
          _warehouseSubMenuIndex = 0; // Товары
        }
      });
    }
  }

  // Проверка доступа к разделу по роли
  bool _canAccessSection(String section) {
    if (_userRole == null) return false;
    
    // Для кладовщика (storekeeper) только Склад и Настройки
    if (_userRole == 'UserRole.storekeeper') {
      return section == 'warehouse' || section == 'settings';
    }
    
    // Остальные роли имеют доступ ко всему
    return true;
  }

  // Экраны для подменю Склад
  Widget _getWarehouseScreen() {
    if (_warehouseSubMenuIndex == null) {
      return const WarehouseScreen(); // По умолчанию показываем Товары
    }
    switch (_warehouseSubMenuIndex) {
      case 0:
        return const WarehouseScreen(); // Товары
      case 1:
        return const IncomingListScreen(); // Оприходование
      case 2:
        return const WarehouseLocationScreen(); // Расположение
      case 3:
        return const WarehousesScreen(); // Склады
      case 4:
        return const WarehouseTransfersScreen(); // Перемещения
      default:
        return const WarehouseScreen();
    }
  }

  // Заголовок AppBar в зависимости от выбранного раздела
  String _getAppBarTitle() {
    if (_selectedIndex == 1) {
      // Склад - показываем название подменю
      switch (_warehouseSubMenuIndex) {
        case 0:
          return 'Товары';
        case 1:
          return 'Оприходование';
        case 2:
          return 'Расположение';
        case 3:
          return 'Склады';
        case 4:
          return 'Перемещения';
        default:
          return 'Склад';
      }
    }
    
    // Другие разделы
    switch (_selectedIndex) {
      case 0:
        return 'Дашборд';
      case 2:
        return 'Продажи';
      case 3:
        return 'CRM';
      case 4:
        return 'Автомобили';
      case 5:
        return 'Аналитика';
      case 6:
        return 'WhatsApp';
      case 7:
        return 'Настройки';
      default:
        return 'AutoHub B2B';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (isMobile) {
      // Мобильная версия с Drawer и BottomNavigationBar
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        drawer: _buildDrawer(context),
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: AppTheme.borderColor,
            ),
          ),
        ),
        body: _selectedIndex == 1 
            ? _getWarehouseScreen() 
            : _screens[_selectedIndex],
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    } else {
      // Desktop версия с боковым меню
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
                        Image.asset(
                          'assets/icons/auto-plus-logo.png',
                          width: 66,
                          height: 66,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto+',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'B2B платформа',
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
                        if (_canAccessSection('dashboard'))
                          _buildNavItem(
                            icon: Icons.dashboard_outlined,
                            selectedIcon: Icons.dashboard,
                            label: 'Дашборд',
                            index: 0,
                          ),
                        if (_canAccessSection('warehouse'))
                          _buildWarehouseMenu(),
                        if (_canAccessSection('sales'))
                          _buildNavItem(
                            icon: Icons.shopping_bag_outlined,
                            selectedIcon: Icons.shopping_bag,
                            label: 'Продажи',
                            index: 2,
                          ),
                        if (_canAccessSection('crm'))
                          _buildNavItem(
                            icon: Icons.people_outline,
                            selectedIcon: Icons.people,
                            label: 'CRM',
                            index: 3,
                          ),
                        if (_canAccessSection('vehicles'))
                          _buildNavItem(
                            icon: Icons.directions_car_outlined,
                            selectedIcon: Icons.directions_car,
                          label: 'Автомобили',
                          index: 4,
                        ),
                        if (_canAccessSection('analytics'))
                          _buildNavItem(
                            icon: Icons.analytics_outlined,
                            selectedIcon: Icons.analytics,
                            label: 'Аналитика',
                            index: 5,
                          ),
                        if (_canAccessSection('whatsapp'))
                          _buildNavItem(
                            icon: Icons.message_outlined,
                            selectedIcon: Icons.message,
                            label: 'WhatsApp',
                            index: 6,
                          ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        if (_canAccessSection('settings'))
                          _buildNavItem(
                            icon: Icons.settings_outlined,
                            selectedIcon: Icons.settings,
                            label: 'Настройки',
                            index: 7,
                          ),
                        // Кнопка тестовой печати (для отладки)
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.bug_report,
                              color: Colors.orange,
                              size: 20,
                            ),
                            title: const Text(
                              '🧪 Тест печати',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TestPrintSimple(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Нижняя часть - профиль пользователя
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return FutureBuilder<Map<String, dynamic>?>(
                          future: SecureStorageService().getUserData(),
                          builder: (context, snapshot) {
                            String userName = 'Пользователь';
                            String userEmail = '';
                            String? organizationName;
                            
                            if (state is AuthAuthenticated) {
                              userName = state.user.name.isNotEmpty 
                                  ? state.user.name 
                                  : state.user.email.split('@')[0];
                              userEmail = state.user.email;
                            }
                            
                            if (snapshot.hasData && snapshot.data?['organization'] != null) {
                              organizationName = snapshot.data!['organization']['name'] as String?;
                            }
                            
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
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
                                          if (organizationName != null) ...[
                                            Text(
                                              organizationName!,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ] else ...[
                                            Text(
                                              userEmail,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Основной контент
            Expanded(
              child: _selectedIndex == 1 
                  ? _getWarehouseScreen() 
                  : _screens[_selectedIndex],
            ),
          ],
        ),
      );
    }
  }

  String _getApprarTitle() {
    if (_selectedIndex == 1) {
      switch (_warehouseSubMenuIndex) {
        case 0:
          return 'Товары';
        case 1:
          return 'Оприходование';
        case 2:
          return 'Расположение';
        case 3:
          return 'Склады';
        case 4:
          return 'Перемещения';
        default:
          return 'Склад';
      }
    }
    switch (_selectedIndex) {
      case 0:
        return 'Дашборд';
      case 2:
        return 'Продажи';
      case 3:
        return 'CRM';
      case 4:
        return 'Автомобили';
      case 5:
        return 'Аналитика';
      case 6:
        return 'WhatsApp';
      case 7:
        return 'Настройки';
      default:
        return 'Auto+ Pro';
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      child: Column(
        children: [
          // Логотип
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Row(
              children: [
                Image.asset(
                  'assets/icons/auto-plus-logo.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto+',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'B2B платформа',
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
                if (_canAccessSection('dashboard'))
                  _buildDrawerNavItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'Дашборд',
                    index: 0,
                    context: context,
                  ),
                if (_canAccessSection('warehouse'))
                  _buildDrawerWarehouseMenu(context),
                // Модуль "Найти запчасть"
                ListTile(
                  leading: const Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text(
                    'Найти запчасть',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Закрыть drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FindPartScreen(),
                      ),
                    );
                  },
                ),
                if (_canAccessSection('sales'))
                  _buildDrawerNavItem(
                    icon: Icons.shopping_bag_outlined,
                    selectedIcon: Icons.shopping_bag,
                    label: 'Продажи',
                    index: 2,
                    context: context,
                  ),
                if (_canAccessSection('crm'))
                  _buildDrawerNavItem(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'CRM',
                    index: 3,
                    context: context,
                  ),
                if (_canAccessSection('vehicles'))
                  _buildDrawerNavItem(
                    icon: Icons.directions_car_outlined,
                    selectedIcon: Icons.directions_car,
                    label: 'Автомобили',
                    index: 4,
                    context: context,
                  ),
                if (_canAccessSection('analytics'))
                  _buildDrawerNavItem(
                    icon: Icons.analytics_outlined,
                    selectedIcon: Icons.analytics,
                    label: 'Аналитика',
                    index: 5,
                    context: context,
                  ),
                if (_canAccessSection('whatsapp'))
                  _buildDrawerNavItem(
                    icon: Icons.message_outlined,
                    selectedIcon: Icons.message,
                    label: 'WhatsApp',
                    index: 6,
                    context: context,
                  ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                if (_canAccessSection('settings'))
                  _buildDrawerNavItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Настройки',
                    index: 7,
                    context: context,
                  ),
                // Кнопка тестовой печати (для отладки)
                ListTile(
                  leading: const Icon(
                    Icons.bug_report,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    '🧪 Тест печати',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Закрыть drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TestPrintSimple(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Профиль пользователя
          Container(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                return FutureBuilder<Map<String, dynamic>?>(
                  future: SecureStorageService().getUserData(),
                  builder: (context, snapshot) {
                    String userName = 'Пользователь';
                    String userEmail = '';
                    String? organizationName;
                    
                    if (state is AuthAuthenticated) {
                      userName = state.user.name.isNotEmpty 
                          ? state.user.name 
                          : state.user.email.split('@')[0];
                      userEmail = state.user.email;
                    }
                    
                    if (snapshot.hasData && snapshot.data?['organization'] != null) {
                      organizationName = snapshot.data!['organization']['name'] as String?;
                    }
                    
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
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
                                  if (organizationName != null) ...[
                                    Text(
                                      organizationName!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else ...[
                                    Text(
                                      userEmail,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    // Показываем только основные разделы в BottomNavigationBar
    final allSections = [
      {'index': 0, 'icon': Icons.dashboard, 'label': 'Дашборд', 'section': 'dashboard'},
      {'index': 1, 'icon': Icons.inventory_2, 'label': 'Склад', 'section': 'warehouse'},
      {'index': 2, 'icon': Icons.shopping_bag, 'label': 'Продажи', 'section': 'sales'},
      {'index': 4, 'icon': Icons.directions_car, 'label': 'Авто', 'section': 'vehicles'},
      {'index': 5, 'icon': Icons.analytics, 'label': 'Аналитика', 'section': 'analytics'},
    ];

    // Фильтруем разделы на основе роли пользователя
    final mainSections = allSections.where((section) => 
      _canAccessSection(section['section'] as String)
    ).toList();

    // Если нет доступных разделов, возвращаем пустой виджет
    if (mainSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return BottomNavigationBar(
      currentIndex: mainSections.indexWhere((s) => s['index'] == _selectedIndex).clamp(0, mainSections.length - 1),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondary,
      backgroundColor: AppTheme.surfaceColor,
      elevation: 8,
      onTap: (index) {
        setState(() {
          _selectedIndex = mainSections[index]['index'] as int;
          if (_selectedIndex == 1 && _warehouseSubMenuIndex == null) {
            _warehouseSubMenuIndex = 0;
          }
        });
      },
      items: mainSections.map((section) {
        return BottomNavigationBarItem(
          icon: Icon(section['icon'] as IconData),
          label: section['label'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildDrawerNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = _selectedIndex == index;
    
    return ListTile(
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      onTap: () {
        Navigator.of(context).pop();
        setState(() {
          _selectedIndex = index;
          if (index != 1) {
            _warehouseMenuExpanded = false;
            _warehouseSubMenuIndex = null;
          }
        });
      },
    );
  }

  Widget _buildDrawerWarehouseMenu(BuildContext context) {
    final isSelected = _selectedIndex == 1;
    
    return ExpansionTile(
      leading: Icon(
        isSelected ? Icons.inventory_2 : Icons.inventory_2_outlined,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
      title: Text(
        'Склад',
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      initiallyExpanded: _warehouseMenuExpanded && isSelected,
      onExpansionChanged: (expanded) {
        setState(() {
          _warehouseMenuExpanded = expanded;
          if (expanded) {
            _selectedIndex = 1;
            if (_warehouseSubMenuIndex == null) {
              _warehouseSubMenuIndex = 0;
            }
          }
        });
      },
      children: [
        _buildDrawerSubMenuItem(
          icon: Icons.inventory_2_outlined,
          label: 'Товары',
          subIndex: 0,
          context: context,
        ),
        _buildDrawerSubMenuItem(
          icon: Icons.receipt_long_outlined,
          label: 'Оприходование',
          subIndex: 1,
          context: context,
        ),
        _buildDrawerSubMenuItem(
          icon: Icons.location_on_outlined,
          label: 'Расположение',
          subIndex: 2,
          context: context,
        ),
        _buildDrawerSubMenuItem(
          icon: Icons.warehouse_outlined,
          label: 'Склады',
          subIndex: 3,
          context: context,
        ),
        _buildDrawerSubMenuItem(
          icon: Icons.swap_horiz,
          label: 'Перемещения',
          subIndex: 4,
          context: context,
        ),
      ],
    );
  }

  Widget _buildDrawerSubMenuItem({
    required IconData icon,
    required String label,
    required int subIndex,
    required BuildContext context,
  }) {
    final isSelected = _selectedIndex == 1 && _warehouseSubMenuIndex == subIndex;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      onTap: () {
        Navigator.of(context).pop();
        setState(() {
          _selectedIndex = 1;
          _warehouseSubMenuIndex = subIndex;
        });
      },
    );
  }

  Widget _buildWarehouseMenu() {
    final isSelected = _selectedIndex == 1;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_selectedIndex == 1) {
                    // Если уже выбран Склад, просто открываем/закрываем подменю
                    _warehouseMenuExpanded = !_warehouseMenuExpanded;
                    if (!_warehouseMenuExpanded) {
                      _warehouseSubMenuIndex = null;
                    } else if (_warehouseSubMenuIndex == null) {
                      _warehouseSubMenuIndex = 0; // По умолчанию Товары
                    }
                  } else {
                    // Если Склад не выбран, открываем его и подменю
                    _selectedIndex = 1;
                    _warehouseMenuExpanded = true;
                    _warehouseSubMenuIndex = 0; // По умолчанию Товары
                  }
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
                      isSelected ? Icons.inventory_2 : Icons.inventory_2_outlined,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Склад',
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      _warehouseMenuExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Подменю
        if (_warehouseMenuExpanded && isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Column(
              children: [
                _buildSubMenuItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Товары',
                  subIndex: 0,
                ),
                _buildSubMenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Оприходование',
                  subIndex: 1,
                ),
                _buildSubMenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Расположение',
                  subIndex: 2,
                ),
                _buildSubMenuItem(
                  icon: Icons.warehouse_outlined,
                  label: 'Склады',
                  subIndex: 3,
                ),
                _buildSubMenuItem(
                  icon: Icons.swap_horiz,
                  label: 'Перемещения',
                  subIndex: 4,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String label,
    required int subIndex,
  }) {
    final isSelected = _selectedIndex == 1 && _warehouseSubMenuIndex == subIndex;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = 1;
              _warehouseSubMenuIndex = subIndex;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              if (index != 1) {
                _warehouseMenuExpanded = false;
                _warehouseSubMenuIndex = null;
              }
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
