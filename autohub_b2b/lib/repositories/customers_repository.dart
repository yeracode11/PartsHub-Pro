import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/models/customer_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/database/database.dart';

class CustomersRepository {
  final AppDatabase _db;
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  CustomersRepository(this._db);

  Future<List<CustomerModel>> getCustomers() async {
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get('/api/customers');
        final List<dynamic> data = response.data;
        final customers = data.map((j) => CustomerModel.fromJson(j)).toList();
        await _cacheCustomers(customers);
        return customers;
      } catch (e) {
        debugPrint('[CustomersRepo] API failed, falling back to cache: $e');
        final cached = await _getFromCache();
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    }
    return _getFromCache();
  }

  bool get isOffline => !_connectivity.isOnline;

  Future<List<CustomerModel>> _getFromCache() async {
    final rows = await _db.getAllCustomers();
    return rows.map(_mapDriftToModel).toList();
  }

  Future<void> _cacheCustomers(List<CustomerModel> customers) async {
    try {
      await _db.batch((batch) async {
        batch.deleteAll(_db.customers);
        for (final c in customers) {
          batch.insert(
            _db.customers,
            CustomersCompanion.insert(
              id: Value(c.id ?? 0),
              name: c.name,
              phone: c.phone,
              email: Value(c.email),
              carBrand: Value(c.carBrand),
              carModel: Value(c.carModel),
              carYear: Value(c.carYear),
              vin: Value(c.vin),
              notes: Value(c.notes),
              synced: const Value(true),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[CustomersRepo] Cache write failed: $e');
    }
  }

  CustomerModel _mapDriftToModel(Customer row) {
    return CustomerModel(
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      carBrand: row.carBrand,
      carModel: row.carModel,
      carYear: row.carYear,
      vin: row.vin,
      notes: row.notes,
      synced: row.synced,
      createdAt: row.createdAt,
    );
  }
}
