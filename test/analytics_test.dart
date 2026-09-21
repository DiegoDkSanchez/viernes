import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/app.dart';
import 'package:viernes/core/app_services.dart';
import 'package:viernes/features/analytics/domain/daily_revenue.dart';
import 'package:viernes/features/auth/domain/auth_repository.dart';
import 'package:viernes/features/orders/domain/orders.dart';
import 'fakes.dart';

CustomerOrder order(
  String id,
  int cents,
  DateTime? delivered, {
  OrderStatus status = OrderStatus.delivered,
}) => CustomerOrder(
  id: id,
  name: id,
  address: 'Address',
  creator: const AppUser('a', 'Ana'),
  status: status,
  createdAt: DateTime(2025),
  deliveredAt: delivered,
  lines: [
    OrderLine(itemId: 'b', name: 'Burger', priceCents: cents, quantity: 2),
  ],
);

void main() {
  test(
    'sums cents and quantities by local delivery day, excluding undelivered',
    () {
      final days = dailyRevenue([
        order('a', 101, DateTime(2026, 9, 1, 1)),
        order('b', 202, DateTime(2026, 9, 1, 23, 59)),
        order('c', 300, DateTime(2026, 9, 2)),
        order('d', 999, null),
        order('e', 999, DateTime(2026, 9, 2), status: OrderStatus.pending),
      ]);
      expect(days.map((d) => d.date), [
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 1),
      ]);
      expect(days.map((d) => d.totalCents), [600, 606]);
      expect(dailyRevenue([]), isEmpty);
      final utc = DateTime.utc(2026, 9, 3, 1);
      final local = utc.toLocal();
      expect(
        dailyRevenue([order('utc', 1, utc)]).single.date,
        DateTime(local.year, local.month, local.day),
      );
    },
  );

  testWidgets('third tab shows live delivered revenue and handles empty data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orders = FakeOrders();
    addTearDown(orders.changes.close);
    orders.items.addAll([
      order('a', 550, DateTime(2026, 9, 1)),
      order('missing', 9000, null),
      order('pending', 8000, null, status: OrderStatus.pending),
    ]);
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          auth: FakeAuth(user: const AppUser('a', 'Ana')),
          orders: orders,
          catalog: FakeCatalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .last
          .label,
      'Analíticas',
    );
    await tester.tap(find.text('Analíticas'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresos diarios'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsTotal'))).data,
      contains('11,00'),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    await orders.delete('a');
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay ingresos por entregas'), findsOneWidget);
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos pendientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
