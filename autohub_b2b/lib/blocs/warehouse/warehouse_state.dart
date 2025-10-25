import 'package:equatable/equatable.dart';
import 'package:autohub_b2b/models/item_model.dart';

abstract class WarehouseState extends Equatable {
  const WarehouseState();

  @override
  List<Object?> get props => [];
}

class WarehouseInitial extends WarehouseState {}

class WarehouseLoading extends WarehouseState {}

class WarehouseLoaded extends WarehouseState {
  final List<ItemModel> items;
  final String? currentCategory;
  final String? searchQuery;

  const WarehouseLoaded({
    required this.items,
    this.currentCategory,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [items, currentCategory, searchQuery];

  WarehouseLoaded copyWith({
    List<ItemModel>? items,
    String? currentCategory,
    String? searchQuery,
  }) {
    return WarehouseLoaded(
      items: items ?? this.items,
      currentCategory: currentCategory ?? this.currentCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class WarehouseError extends WarehouseState {
  final String message;

  const WarehouseError(this.message);

  @override
  List<Object?> get props => [message];
}

