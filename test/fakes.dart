import 'package:viernes/features/analytics/domain/sale_day.dart';
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

class FakeAnalytics implements AnalyticsRepository {
  final days = <DateTime>[];
  final expenses = <String, List<Expense>>{};
  final changes = StreamController<void>.broadcast();
  int nextId = 0;
  @override
  Stream<List<DateTime>> watchDays() async* {
    List<DateTime> current() => [...days]..sort((a, b) => b.compareTo(a));
    yield current();
    await for (final _ in changes.stream) {
      yield current();
    }
  }

  @override
  Future<void> addDay(DateTime date) async {
    date = calendarDate(date);
    if (!days.contains(date)) days.add(date);
    changes.add(null);
  }

  @override
  Stream<List<Expense>> watchExpenses(DateTime date) async* {
    yield [...?expenses[saleDayId(date)]];
    await for (final _ in changes.stream) {
      yield [...?expenses[saleDayId(date)]];
    }
  }

  @override
  String newExpenseId(DateTime date) => '${nextId++}';
  @override
  Future<void> saveExpense(DateTime date, Expense expense) async {
    validateExpense(expense);
    final items = expenses.putIfAbsent(saleDayId(date), () => []);
    items.removeWhere((e) => e.id == expense.id);
    items.add(expense);
    changes.add(null);
  }

  @override
  Future<void> deleteExpense(DateTime date, String id) async {
    expenses[saleDayId(date)]?.removeWhere((e) => e.id == id);
    changes.add(null);
  }
}
