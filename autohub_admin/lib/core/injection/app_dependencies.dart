import 'package:dio/dio.dart';

import '../network/dio_factory.dart';
import '../storage/secure_token_storage.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/subscriptions/data/subscriptions_api.dart';
import '../../features/transactions/data/transactions_api.dart';
import '../../features/users/data/users_api.dart';
import '../../features/users/data/users_repository.dart';

/// Simple composition root — keeps constructors explicit without DI frameworks.
class AppDependencies {
  AppDependencies._({
    required this.tokenStorage,
    required this.dio,
    required this.authApi,
    required this.usersApi,
    required this.usersRepository,
    required this.subscriptionsApi,
    required this.transactionsApi,
    required this.dashboardRepository,
  });

  final SecureTokenStorage tokenStorage;
  final Dio dio;
  final AuthApi authApi;
  final UsersApi usersApi;
  final UsersRepository usersRepository;
  final SubscriptionsApi subscriptionsApi;
  final TransactionsApi transactionsApi;
  final DashboardRepository dashboardRepository;

  factory AppDependencies.bootstrap() {
    final tokens = SecureTokenStorage();
    final dio = DioFactory(tokens).create();
    final authApi = AuthApi(dio);
    final usersApi = UsersApi(dio);
    final usersRepository = UsersRepository(usersApi);
    final subscriptionsApi = SubscriptionsApi(dio);
    final transactionsApi = TransactionsApi(dio);
    final dashboardRepository = DashboardRepository(
      usersApi: usersApi,
      subscriptionsApi: subscriptionsApi,
      transactionsApi: transactionsApi,
    );

    return AppDependencies._(
      tokenStorage: tokens,
      dio: dio,
      authApi: authApi,
      usersApi: usersApi,
      usersRepository: usersRepository,
      subscriptionsApi: subscriptionsApi,
      transactionsApi: transactionsApi,
      dashboardRepository: dashboardRepository,
    );
  }
}
