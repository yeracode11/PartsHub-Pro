import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Items table - запчасти
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get category => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get price => real()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  TextColumn get condition => text()(); // new, used, refurbished
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Orders table - заказы
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get status => text()(); // pending, processing, completed, cancelled
  TextColumn get paymentStatus => text()(); // unpaid, paid, partial
  TextColumn get notes => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// OrderItems - позиции в заказе
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get quantity => integer()();
  RealColumn get price => real()();
  RealColumn get subtotal => real()();
}

// Customers table - клиенты
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withLength(min: 10, max: 20)();
  TextColumn get email => text().nullable()();
  TextColumn get carBrand => text().nullable()();
  TextColumn get carModel => text().nullable()();
  TextColumn get carYear => text().nullable()();
  TextColumn get vin => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Movements table - движение товара
class Movements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  TextColumn get type => text()(); // in, out, adjustment
  IntColumn get quantity => integer()();
  TextColumn get reason => text().nullable()();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Users table - пользователи
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text().unique()(); // Firebase UID
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get role => text()(); // owner, manager, storekeeper, worker
  TextColumn get businessType => text()(); // dismantler, service, carwash
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// SyncQueue - очередь синхронизации
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncTableName => text()(); // переименовано из tableName
  TextColumn get operation => text()(); // create, update, delete
  IntColumn get recordId => integer()();
  TextColumn get data => text()(); // JSON данные
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Items,
  Orders,
  OrderItems,
  Customers,
  Movements,
  Users,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Queries for Items
  Future<List<Item>> getAllItems() => select(items).get();
  Future<List<Item>> getItemsByCategory(String category) =>
      (select(items)..where((tbl) => tbl.category.equals(category))).get();
  Future<Item?> getItemById(int id) =>
      (select(items)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  Future<int> insertItem(ItemsCompanion item) => into(items).insert(item);
  Future<bool> updateItem(ItemsCompanion item) => update(items).replace(item);
  Future<int> deleteItem(int id) =>
      (delete(items)..where((tbl) => tbl.id.equals(id))).go();

  // Queries for Orders
  Future<List<Order>> getAllOrders() => select(orders).get();
  Future<List<Order>> getOrdersByStatus(String status) =>
      (select(orders)..where((tbl) => tbl.status.equals(status))).get();
  Future<Order?> getOrderById(int id) =>
      (select(orders)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  Future<int> insertOrder(OrdersCompanion order) => into(orders).insert(order);
  Future<bool> updateOrder(OrdersCompanion order) => update(orders).replace(order);

  // Queries for Customers
  Future<List<Customer>> getAllCustomers() => select(customers).get();
  Future<Customer?> getCustomerById(int id) =>
      (select(customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);
  Future<bool> updateCustomer(CustomersCompanion customer) =>
      update(customers).replace(customer);

  // Queries for Movements
  Future<List<Movement>> getAllMovements() => select(movements).get();
  Future<List<Movement>> getMovementsByItemId(int itemId) =>
      (select(movements)..where((tbl) => tbl.itemId.equals(itemId))).get();
  Future<int> insertMovement(MovementsCompanion movement) =>
      into(movements).insert(movement);

  // Queries for SyncQueue
  Future<List<SyncQueueData>> getUnsyncedItems() =>
      (select(syncQueue)..where((tbl) => tbl.synced.equals(false))).get();
  Future<int> insertSyncItem(SyncQueueCompanion item) =>
      into(syncQueue).insert(item);
  Future<int> markSynced(int id) => (update(syncQueue)
        ..where((tbl) => tbl.id.equals(id)))
      .write(const SyncQueueCompanion(synced: Value(true)));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'autohub_db.sqlite'));
    return NativeDatabase(file);
  });
}

