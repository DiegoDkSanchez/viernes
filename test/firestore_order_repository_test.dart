import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/orders/data/firestore_order_repository.dart';
import 'package:viernes/features/orders/domain/orders.dart';

// SDK boundary fakes let this regression reproduce index failures, which the
// Firestore emulator does not enforce, without a live project or credentials.
class QueryFixture implements CollectionReference<Map<String, dynamic>> {
  QueryFixture(this.events, {this.ordered});
  final Stream<QuerySnapshot<Map<String, dynamic>>> events;
  final QueryFixture? ordered;
  String? status;
  int subscriptions = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      expect(invocation.positionalArguments.single, 'status');
      status = invocation.namedArguments[#isEqualTo] as String;
      return this;
    }
    if (invocation.memberName == #orderBy) {
      expect(invocation.positionalArguments.single, 'createdAt');
      expect(invocation.namedArguments[#descending], true);
      return ordered!;
    }
    if (invocation.memberName == #snapshots) {
      subscriptions++;
      return events;
    }
    return super.noSuchMethod(invocation);
  }
}

class DatabaseFixture implements FirebaseFirestore {
  DatabaseFixture(this.query);
  final QueryFixture query;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'shops/main/orders');
    return query;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SnapshotFixture implements QuerySnapshot<Map<String, dynamic>> {
  SnapshotFixture(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DocumentFixture implements QueryDocumentSnapshot<Map<String, dynamic>> {
  DocumentFixture(this.id, this.time, this.status);
  @override
  final String id;
  final DateTime? time;
  final OrderStatus status;
  @override
  Map<String, dynamic> data() => {
    'name': id,
    'address': 'Street',
    'creatorId': 'user',
    'creatorName': 'Ana',
    'status': status.name,
    'createdAt': time == null ? null : Timestamp.fromDate(time!),
    'deliveredAt': null,
    'lines': [
      {
        'itemId': 'burger',
        'name': 'Burger',
        'priceCents': 550,
        'quantity': 1,
        'options': <String>[],
      },
    ],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final status in OrderStatus.values) {
    test(
      'index building falls back to live ${status.name} query with stable sorting',
      () async {
        final older = DateTime(2026, 9, 1), newer = DateTime(2026, 9, 2);
        final query = QueryFixture(
          Stream.fromIterable([
            SnapshotFixture([
              DocumentFixture('old', older, status),
              DocumentFixture('a', newer, status),
              DocumentFixture('z', newer, status),
              DocumentFixture('unresolved', null, status),
            ]),
            SnapshotFixture([DocumentFixture('old', older, status)]),
          ]),
          ordered: QueryFixture(
            Stream.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'failed-precondition',
                message:
                    'The query requires an index. That index is currently building.',
              ),
            ),
          ),
        );
        final values = await FirestoreOrderRepository(
          DatabaseFixture(query),
        ).watchOrders(status).toList();
        expect(query.status, status.name);
        expect(query.subscriptions, 1);
        expect(values.first.map((o) => o.id), ['unresolved', 'z', 'a', 'old']);
        expect(values.last.map((o) => o.id), ['old']);
        expect(values.first.first.totalCents, 550);
      },
    );
  }
  test('healthy indexed query does not subscribe to fallback', () async {
    final query = QueryFixture(
      const Stream.empty(),
      ordered: QueryFixture(
        Stream.value(
          SnapshotFixture([
            DocumentFixture('one', DateTime(2026), OrderStatus.pending),
          ]),
        ),
      ),
    );
    final orders = await FirestoreOrderRepository(
      DatabaseFixture(query),
    ).watchOrders(OrderStatus.pending).first;
    expect(orders.single.id, 'one');
    expect(query.subscriptions, 0);
  });
  test(
    'permission and unrelated precondition errors propagate without fallback',
    () async {
      for (final code in [
        'permission-denied',
        'unavailable',
        'failed-precondition',
      ]) {
        final error = FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
          message: 'Other failure',
        );
        final query = QueryFixture(
          const Stream.empty(),
          ordered: QueryFixture(Stream.error(error)),
        );
        await expectLater(
          FirestoreOrderRepository(
            DatabaseFixture(query),
          ).watchOrders(OrderStatus.pending),
          emitsError(same(error)),
        );
        expect(query.subscriptions, 0);
      }
    },
  );
}
