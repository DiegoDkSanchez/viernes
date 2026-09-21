import 'dart:async';
import 'package:viernes/features/auth/domain/auth_repository.dart';
import 'package:viernes/features/catalog/domain/catalog.dart';
import 'package:viernes/features/orders/domain/orders.dart';

class FakeAuth implements AuthRepository {
  AppUser? user;
  FakeAuth({this.user});
  @override
  Stream<AppUser?> watchUser() => Stream.value(user);
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
}

class FakeCatalog implements CatalogRepository {
  List<MenuItem> items = [
    MenuItem(
      id: 'burger',
      name: 'Hamburguesa con papas',
      priceCents: 550,
      options: ['Cebolla', 'Queso'],
    ),
  ];
  @override
  Stream<List<MenuItem>> watchMenu() => Stream.value(items);
  @override
  Future<void> save(MenuItem item) async {
    items.add(item);
  }
}

class FakeOrders implements OrderRepository {
  final List<CustomerOrder> items = [];
  final changes = StreamController<void>.broadcast();
  @override
  String newId() => 'draft';
  @override
  Future<void> create(CustomerOrder order) async {
    items.add(order);
    changes.add(null);
  }

  @override
  Stream<List<CustomerOrder>> watchOrders(OrderStatus status) async* {
    yield items.where((o) => o.status == status).toList();
    await for (final _ in changes.stream) {
      yield items.where((o) => o.status == status).toList();
    }
  }

  @override
  Future<void> update(CustomerOrder order) async {
    final i = items.indexWhere((o) => o.id == order.id);
    final old = items[i];
    items[i] = CustomerOrder(
      id: old.id,
      name: order.name,
      address: order.address,
      deliveryTimeMinutes: order.deliveryTimeMinutes,
      lines: order.lines,
      creator: old.creator,
      status: old.status,
      createdAt: old.createdAt,
      deliveredAt: old.deliveredAt,
    );
    changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((o) => o.id == id);
    changes.add(null);
  }

  @override
  Future<void> setStatus(String id, OrderStatus status) async {
    final i = items.indexWhere((o) => o.id == id),
        old = items.firstWhere((o) => o.id == id);
    items[i] = CustomerOrder(
      id: id,
      name: old.name,
      address: old.address,
      deliveryTimeMinutes: old.deliveryTimeMinutes,
      lines: old.lines,
      creator: old.creator,
      status: status,
    );
    changes.add(null);
  }
}
