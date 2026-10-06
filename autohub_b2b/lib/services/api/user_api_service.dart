import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';

class UserApiService {
  final ApiClient _apiClient;

  UserApiService(this._apiClient);

  /// Обновить профиль пользователя
  Future<UserModel> updateProfile({
    required String name,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/users/profile',
        data: {
          'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        },
      );

      final userData = response.data;
      final userModel = UserModel(
        uid: userData['id'],
        name: userData['name'] ?? 'User',
        email: userData['email'],
        role: _parseRole(userData['role']),
        businessType: _parseBusinessType(userData['organization']?['businessType']),
        createdAt: DateTime.parse(userData['createdAt']),
      );
      
      // Сохраняем обновленные данные организации в storage
      final storage = SecureStorageService();
      final currentUserData = await storage.getUserData();
      if (currentUserData != null) {
        final org = userData['organization'];
        await storage.saveUserData({
          ...currentUserData,
          'name': userModel.name,
          'email': userModel.email,
          if (userData['phone'] != null) 'phone': userData['phone'],
          if (org != null) 'organization': org,
        });
      }
      
      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  UserRole _parseRole(String? role) {
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'storekeeper':
        return UserRole.storekeeper;
      case 'worker':
        return UserRole.worker;
      case 'sto':
        return UserRole.sto;
      default:
        return UserRole.owner;
    }
  }

  BusinessType _parseBusinessType(String? type) {
    switch (type) {
      case 'service':
        return BusinessType.service;
      case 'dismantler':
        return BusinessType.dismantler;
      case 'carwash':
        return BusinessType.carwash;
      default:
        return BusinessType.service;
    }
  }
}

