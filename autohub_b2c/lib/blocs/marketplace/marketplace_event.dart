// Events
abstract class MarketplaceEvent {}

class MarketplaceLoadRequested extends MarketplaceEvent {}

class MarketplaceSearchRequested extends MarketplaceEvent {
  final String query;
  MarketplaceSearchRequested(this.query);
}

class MarketplaceCategoryFilterRequested extends MarketplaceEvent {
  final String category;
  MarketplaceCategoryFilterRequested(this.category);
}
