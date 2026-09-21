class MenuItem {
  MenuItem({
    required this.id,
    required this.name,
    required this.priceCents,
    List<String> options = const [],
    this.active = true,
  }) : options = List.unmodifiable(options);
  final String id;
  final String name;
  final int priceCents;
  final List<String> options;
  final bool active;
}

abstract interface class CatalogRepository {
  Stream<List<MenuItem>> watchMenu();
  Future<void> save(MenuItem item);
}

class SaveMenuItem {
  const SaveMenuItem(this.repository);
  final CatalogRepository repository;
  Future<void> call(MenuItem item) {
    if (item.name.trim().isEmpty ||
        item.name.length > 100 ||
        item.priceCents < 1 ||
        item.priceCents > 1000000 ||
        item.options.length > 8 ||
        item.options.toSet().length != item.options.length ||
        item.options.any((o) => o.trim().isEmpty || o.length > 50)) {
      throw const FormatException('invalidMenu');
    }
    return repository.save(item);
  }
}

class WatchMenu {
  const WatchMenu(this.repository);
  final CatalogRepository repository;
  Stream<List<MenuItem>> call() => repository.watchMenu();
}
