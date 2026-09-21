import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/orders.dart';

// A shared shop namespace, never scoped to the current user's UID.
class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(FirebaseFirestore db)
    : _orders = db.collection('shops/main/orders');
  final CollectionReference<Map<String, dynamic>> _orders;
  @override
  String newId() => _orders.doc().id;
  @override
  Stream<List<CustomerOrder>> watchOrders(OrderStatus status) async* {
    final filtered = _orders.where('status', isEqualTo: status.name);
    try {
      yield* _decode(filtered.orderBy('createdAt', descending: true));
    } on FirebaseException catch (error) {
      // An index may be deployed but still building. Keep the live list usable
      // with a single-field query; authentication/network errors still surface.
      if (error.code != 'failed-precondition' ||
          !(error.message ?? '').toLowerCase().contains('index')) {
        rethrow;
      }
      yield* _decode(filtered, sortLocally: true);
    }
  }

  Stream<List<CustomerOrder>> _decode(
    Query<Map<String, dynamic>> query, {
    bool sortLocally = false,
  }) => query.snapshots().map((snapshot) {
    final orders = snapshot.docs.map((doc) {
      final d = doc.data();
      return CustomerOrder(
        id: doc.id,
        name: d['name'] as String,
        address: d['address'] as String,
        deliveryTimeMinutes: d['deliveryTimeMinutes'] as int?,
        creator: AppUser(d['creatorId'] as String, d['creatorName'] as String),
        status: OrderStatus.values.byName(d['status'] as String),
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),
        lines: (d['lines'] as List)
            .map(
              (l) => OrderLine(
                itemId: l['itemId'] as String,
                name: l['name'] as String,
                priceCents: l['priceCents'] as int,
                quantity: l['quantity'] as int,
                options: List<String>.from(l['options'] as List),
              ),
            )
            .toList(),
      );
    }).toList();
    if (sortLocally) {
      orders.sort((a, b) {
        // Unresolved server timestamps appear first until acknowledged.
        if (a.createdAt == null && b.createdAt != null) return -1;
        if (b.createdAt == null && a.createdAt != null) return 1;
        final time = a.createdAt == null
            ? 0
            : b.createdAt!.compareTo(a.createdAt!);
        return time == 0 ? b.id.compareTo(a.id) : time;
      });
    }
    return orders;
  });
  @override
  Future<void> create(CustomerOrder order) async {
    // A stable draft ID and transaction prevent duplicate orders on retries.
    await _orders.firestore.runTransaction((transaction) async {
      final ref = _orders.doc(order.id);
      if ((await transaction.get(ref)).exists) return;
      transaction.set(ref, {
        'name': order.name.trim(),
        'address': order.address.trim(),
        'deliveryTimeMinutes': order.deliveryTimeMinutes,
        'creatorId': order.creator.id,
        'creatorName': order.creator.name,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredAt': null,
        'totalCents': order.totalCents,
        'lines': order.lines
            .map(
              (l) => {
                'itemId': l.itemId,
                'name': l.name,
                'priceCents': l.priceCents,
                'quantity': l.quantity,
                'options': l.options,
              },
            )
            .toList(),
      });
    });
  }

  @override
  Future<void> update(CustomerOrder order) => _orders.doc(order.id).update({
    // Patch only editable contents: retain the original author and live status.
    'name': order.name.trim(), 'address': order.address.trim(),
    'deliveryTimeMinutes': order.deliveryTimeMinutes,
    'totalCents': order.totalCents,
    'lines': order.lines
        .map(
          (l) => {
            'itemId': l.itemId,
            'name': l.name,
            'priceCents': l.priceCents,
            'quantity': l.quantity,
            'options': l.options,
          },
        )
        .toList(),
  });

  @override
  Future<void> delete(String id) => _orders.doc(id).delete();

  @override
  Future<void> setStatus(String id, OrderStatus status) =>
      _orders.doc(id).update({
        'status': status.name,
        'deliveredAt': status == OrderStatus.delivered
            ? FieldValue.serverTimestamp()
            : null,
      });
}
