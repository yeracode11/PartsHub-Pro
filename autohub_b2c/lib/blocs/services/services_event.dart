abstract class ServicesEvent {}

class ServicesLoadRequested extends ServicesEvent {}

class ServicesSearchRequested extends ServicesEvent {
  final String query;
  ServicesSearchRequested(this.query);
}
