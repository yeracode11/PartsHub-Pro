import 'users_api.dart';
import 'models/user_entity.dart';

class UsersRepository {
  UsersRepository(this._api);

  final UsersApi _api;

  Future<UsersPageResult> fetchPage({
    required int page,
    required int pageSize,
    String? search,
  }) =>
      _api.listUsers(page: page, pageSize: pageSize, search: search);

  Future<UserEntity> get(String id) => _api.getUser(id);

  Future<UserEntity> create(Map<String, dynamic> body) => _api.createUser(body);

  Future<UserEntity> update(String id, Map<String, dynamic> body) =>
      _api.updateUser(id, body);

  Future<void> delete(String id) => _api.deleteUser(id);
}
