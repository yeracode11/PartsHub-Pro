import '../../models/product_model.dart';

// States
abstract class MarketplaceState {}

class MarketplaceInitial extends MarketplaceState {}

class MarketplaceLoading extends MarketplaceState {}

class MarketplaceLoaded extends MarketplaceState {
  final List<Product> products;
  MarketplaceLoaded(this.products);
}

class MarketplaceError extends MarketplaceState {
  final String message;
  MarketplaceError(this.message);
}
