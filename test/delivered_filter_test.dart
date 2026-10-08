import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/app.dart';
import 'package:viernes/core/app_services.dart';
import 'package:viernes/features/auth/domain/auth_repository.dart';
import 'package:viernes/features/orders/domain/orders.dart';
import 'fakes.dart';

void main() {
  testWidgets('saved sale days filter deliveries, counts and live changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final analytics = FakeAnalytics();
    final orders = FakeOrders();
    addTearDown(analytics.changes.close);
    addTearDown(orders.changes.close);
    await analytics.addDay(DateTime(2026, 9, 1));
    await analytics.addDay(DateTime(2026, 9, 2));
    CustomerOrder delivered(String id, DateTime? date) => CustomerOrder(
      id: id,
      name: id,
      address: 'Address',
      lines: [],
      creator: const AppUser('a', 'Ana'),
      status: OrderStatus.delivered,
      deliveredAt: date,
    );
    orders.items.addAll([
      delivered('Early', DateTime(2026, 9, 1)),
      delivered('Late', DateTime(2026, 9, 1, 23, 59)),
      delivered('Next day', DateTime(2026, 9, 3)),
      delivered('No timestamp', null),
    ]);
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          analytics: analytics,
          orders: orders,
          catalog: FakeCatalog(),
          auth: FakeAuth(user: const AppUser('a', 'Ana')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deliveredDayFilter')), findsNothing);
    await tester.tap(find.text('Entregados'));
    await tester.pumpAndSettle();
    expect(find.text('4 pedidos completados'), findsOneWidget);
    Future<void> select(DateTime? date) async {
      await tester.tap(find.byKey(const ValueKey('deliveredDayFilter')));
      await tester.pumpAndSettle();
      final item = find
          .byWidgetPredicate(
            (w) => w is DropdownMenuItem<DateTime> && w.value == date,
          )
          .last;
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await select(DateTime(2026, 9, 1));
    expect(find.text('2 pedidos completados'), findsOneWidget);
    expect(find.byKey(const ValueKey('Early')), findsOneWidget);
    expect(find.byKey(const ValueKey('Next day')), findsNothing);
    await orders.delete('Early');
    await tester.pumpAndSettle();
    expect(find.text('1 pedidos completados'), findsOneWidget);
    expect(find.byKey(const ValueKey('Late')), findsOneWidget);
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregados'));
    await tester.pumpAndSettle();
    expect(find.text('1 pedidos completados'), findsOneWidget);
    await select(DateTime(2026, 9, 2));
    expect(find.text('No hay entregas en esta fecha'), findsOneWidget);
    expect(find.text('0 pedidos completados'), findsOneWidget);
    await select(null);
    expect(find.text('3 pedidos completados'), findsOneWidget);
    await analytics.addDay(DateTime(2026, 9, 3));
    await tester.pumpAndSettle();
    await select(DateTime(2026, 9, 3));
    expect(find.byKey(const ValueKey('Next day')), findsOneWidget);
    expect(find.text('1 pedidos completados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
