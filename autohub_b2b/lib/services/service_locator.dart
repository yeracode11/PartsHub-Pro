import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/sync_service.dart';
import 'package:autohub_b2b/repositories/items_repository.dart';
import 'package:autohub_b2b/repositories/orders_repository.dart';
import 'package:autohub_b2b/repositories/customers_repository.dart';

/// Lightweight service locator for accessing shared instances.
/// Initialized once in main() before runApp().
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final AppDatabase database;
  late final ConnectivityService connectivity;
  late final SyncService syncService;
  late final ItemsRepository itemsRepository;
  late final OrdersRepository ordersRepository;
  late final CustomersRepository customersRepository;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init(AppDatabase db) async {
    if (_initialized) return;

    database = db;

    connectivity = ConnectivityService();
    await connectivity.init();

    syncService = SyncService();
    syncService.init(db);

    itemsRepository = ItemsRepository(db);
    ordersRepository = OrdersRepository(db);
    customersRepository = CustomersRepository(db);

    _initialized = true;
  }
}
