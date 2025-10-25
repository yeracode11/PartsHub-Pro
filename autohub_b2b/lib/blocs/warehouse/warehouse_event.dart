import 'package:equatable/equatable.dart';
import 'package:autohub_b2b/models/item_model.dart';

abstract class WarehouseEvent extends Equatable {
  const WarehouseEvent();

  @override
  List<Object?> get props => [];
}

class LoadItems extends WarehouseEvent {}

class FilterItemsByCategory extends WarehouseEvent {
  final String category;

  const FilterItemsByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class SearchItems extends WarehouseEvent {
  final String query;

  const SearchItems(this.query);

  @override
  List<Object?> get props => [query];
}

class AddItem extends WarehouseEvent {
  final ItemModel item;

  const AddItem(this.item);

  @override
  List<Object?> get props => [item];
}

class UpdateItem extends WarehouseEvent {
  final ItemModel item;

  const UpdateItem(this.item);

  @override
  List<Object?> get props => [item];
}

class DeleteItem extends WarehouseEvent {
  final int itemId;

  const DeleteItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

