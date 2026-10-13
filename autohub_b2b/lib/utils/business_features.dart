import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';

/// Работает ли организация с автомобилями клиентов (гараж, ТО, авто в заказе).
/// Авторазбору это не нужно: он продаёт запчасти и не ведёт машины клиентов.
/// Гость и неизвестный тип — как раньше, с автомобилями.
bool usesClientVehicles(BuildContext context) {
  final state = context.read<AuthBloc>().state;
  return state is! AuthAuthenticated ||
      state.user.businessType != BusinessType.dismantler;
}
