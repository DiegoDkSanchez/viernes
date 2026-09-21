import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/catalog.dart';

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(FirebaseFirestore db)
    : _menu = db.collection('shops/main/menu');
  final CollectionReference<Map<String, dynamic>> _menu;
  @override
  Stream<List<MenuItem>> watchMenu() => _menu
      .orderBy('name')
      .snapshots()
      .map(
        (s) => s.docs.map((doc) {
          final d = doc.data();
          return MenuItem(
            id: doc.id,
            name: d['name'] as String,
            priceCents: d['priceCents'] as int,
            active: d['active'] as bool,
            options: List<String>.from(d['options'] as List),
          );
        }).toList(),
      );
  @override
  Future<void> save(MenuItem item) =>
      (item.id.isEmpty ? _menu.doc() : _menu.doc(item.id)).set({
        'name': item.name.trim(),
        'priceCents': item.priceCents,
        'options': item.options,
        'active': item.active,
      });
}
