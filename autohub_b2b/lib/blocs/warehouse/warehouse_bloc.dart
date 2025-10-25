import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/warehouse/warehouse_event.dart';
import 'package:autohub_b2b/blocs/warehouse/warehouse_state.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:drift/drift.dart' as drift;

class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  final AppDatabase database;

  WarehouseBloc({required this.database}) : super(WarehouseInitial()) {
    on<LoadItems>(_onLoadItems);
    on<FilterItemsByCategory>(_onFilterByCategory);
    on<SearchItems>(_onSearchItems);
    on<AddItem>(_onAddItem);
    on<UpdateItem>(_onUpdateItem);
    on<DeleteItem>(_onDeleteItem);
  }

  Future<void> _onLoadItems(LoadItems event, Emitter<WarehouseState> emit) async {
    try {
      emit(WarehouseLoading());
      final items = await database.getAllItems();
      final itemModels = items.map(_itemToModel).toList();
      emit(WarehouseLoaded(items: itemModels));
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  Future<void> _onFilterByCategory(
      FilterItemsByCategory event, Emitter<WarehouseState> emit) async {
    try {
      emit(WarehouseLoading());
      final items = await database.getItemsByCategory(event.category);
      final itemModels = items.map(_itemToModel).toList();
      emit(WarehouseLoaded(items: itemModels, currentCategory: event.category));
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  Future<void> _onSearchItems(SearchItems event, Emitter<WarehouseState> emit) async {
    try {
      emit(WarehouseLoading());
      final allItems = await database.getAllItems();
      final filteredItems = allItems
          .where((item) =>
              item.name.toLowerCase().contains(event.query.toLowerCase()) ||
              (item.sku?.toLowerCase().contains(event.query.toLowerCase()) ?? false))
          .toList();
      final itemModels = filteredItems.map(_itemToModel).toList();
      emit(WarehouseLoaded(items: itemModels, searchQuery: event.query));
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  Future<void> _onAddItem(AddItem event, Emitter<WarehouseState> emit) async {
    try {
      final companion = ItemsCompanion(
        name: drift.Value(event.item.name),
        category: drift.Value(event.item.category ?? 'Общее'),
        sku: drift.Value(event.item.sku),
        price: drift.Value(event.item.price),
        quantity: drift.Value(event.item.quantity),
        condition: drift.Value(event.item.condition),
        description: drift.Value(event.item.description),
        imageUrl: drift.Value(event.item.imageUrl),
      );
      await database.insertItem(companion);
      add(LoadItems());
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  Future<void> _onUpdateItem(UpdateItem event, Emitter<WarehouseState> emit) async {
    try {
      final companion = ItemsCompanion(
        id: drift.Value(event.item.id!),
        name: drift.Value(event.item.name),
        category: drift.Value(event.item.category ?? 'Общее'),
        sku: drift.Value(event.item.sku),
        price: drift.Value(event.item.price),
        quantity: drift.Value(event.item.quantity),
        condition: drift.Value(event.item.condition),
        description: drift.Value(event.item.description),
        imageUrl: drift.Value(event.item.imageUrl),
      );
      await database.updateItem(companion);
      add(LoadItems());
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  Future<void> _onDeleteItem(DeleteItem event, Emitter<WarehouseState> emit) async {
    try {
      await database.deleteItem(event.itemId);
      add(LoadItems());
    } catch (e) {
      emit(WarehouseError(e.toString()));
    }
  }

  ItemModel _itemToModel(Item item) {
    return ItemModel(
      id: item.id,
      name: item.name,
      category: item.category,
      sku: item.sku,
      price: item.price,
      quantity: item.quantity,
      condition: item.condition,
      description: item.description,
      imageUrl: item.imageUrl,
      synced: item.synced,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}

