import 'package:viernes/features/analytics/domain/sale_day.dart';
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

  test(
    'summary excludes pending and other days, counts orders not quantities',
    () {
      final date = DateTime(2026, 9, 1);
      final summary = SaleDaySummary(
        date,
        [
          order('a', 101, date),
          order('b', 202, date),
          order('c', 999, DateTime(2026, 9, 2)),
          order('p', 999, date, status: OrderStatus.pending),
        ],
        [const Expense(id: 'e', name: 'Oil', amountCents: 700)],
      );
      expect(summary.salesCents, 606);
      expect(summary.orderCount, 2);
      expect(summary.profitCents, -94);
      expect(
        () =>
            validateExpense(const Expense(id: 'x', name: ' ', amountCents: 1)),
        throwsFormatException,
      );
      expect(
        () => validateExpense(
          const Expense(id: 'x', name: 'Oil', amountCents: 0),
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'manually add a day, cancel, reuse it and retain it across tabs',
    (tester) async {
      final analytics = FakeAnalytics();
      final orders = FakeOrders();
      addTearDown(analytics.changes.close);
      addTearDown(orders.changes.close);
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
      await tester.tap(find.text('Analíticas'));
      await tester.pumpAndSettle();
      expect(find.text('Agrega tu primer día de venta'), findsOneWidget);
      await tester.tap(find.byTooltip('Agregar fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(analytics.days, isEmpty);
      await tester.tap(find.byTooltip('Agregar fecha'));
      await tester.pumpAndSettle();
      final picker = find.byType(DatePickerDialog);
      final localizations = MaterialLocalizations.of(tester.element(picker));
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();
      expect(analytics.days, hasLength(1));
      expect(find.text('Gastos'), findsOneWidget);
      await tester.tap(find.byTooltip('Agregar fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();
      expect(analytics.days, hasLength(1));
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analíticas'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saleDaySelector')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sale days scope live totals and expense management', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orders = FakeOrders();
    final analytics = FakeAnalytics();
    addTearDown(analytics.changes.close);
    await analytics.addDay(DateTime(2026, 9, 1));
    await analytics.addDay(DateTime(2026, 8, 31));
    addTearDown(orders.changes.close);
    orders.items.addAll([
      order('a', 550, DateTime(2026, 9, 1)),
      order('missing', 9000, null),
      order('pending', 8000, null, status: OrderStatus.pending),
    ]);
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          analytics: analytics,
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
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.byKey(const ValueKey('saleDaySelector')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsTotal'))).data,
      contains('11,00'),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay gastos'), findsOneWidget);
    await tester.tap(find.byTooltip('Agregar gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ingredientes');
    await tester.enterText(find.byType(TextFormField).last, '-1');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un precio entre 0.01 y 10000'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '12,50');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingredientes'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsProfit'))).data,
      contains('-1,50'),
    );
    await tester.tap(find.byKey(const ValueKey('saleDaySelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('31').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsTotal'))).data,
      contains('0,00'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsProfit'))).data,
      contains('0,00'),
    );
    await tester.tap(find.byKey(const ValueKey('saleDaySelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('1 sept').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingredientes'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await orders.delete('a');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('analyticsTotal'))).data,
      contains('0,00'),
    );
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos pendientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
