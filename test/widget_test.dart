import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/app.dart';
import 'package:viernes/core/app_services.dart';
import 'package:viernes/features/auth/domain/auth_repository.dart';
import 'package:viernes/features/orders/domain/orders.dart';
import 'package:viernes/features/catalog/domain/catalog.dart';
import 'fakes.dart';

void main() {
  testWidgets('Spanish login is the unauthenticated entry', (tester) async {
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          auth: FakeAuth(),
          orders: FakeOrders(),
          catalog: FakeCatalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsNothing);
  });
  testWidgets(
    'create, deliver, and reopen an order through reference actions',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final orders = FakeOrders();
      addTearDown(orders.changes.close);
      await tester.pumpWidget(
        OrdersApp(
          services: AppServices(
            auth: FakeAuth(user: const AppUser('alice', 'Ana')),
            orders: orders,
            catalog: FakeCatalog(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedidos pendientes'), findsOneWidget);
      await tester.tap(find.text('Nuevo pedido'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Carlos Mendoza',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Av. Principal 123',
      );
      await tester.tap(find.byTooltip('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Queso'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar pedido'));
      await tester.tap(find.text('Guardar pedido'));
      await tester.pumpAndSettle();
      expect(orders.items.single.deliveryTimeMinutes, isNull);
      expect(orders.items.single.totalCents, 550);
      expect(orders.items.single.creator.id, 'alice');
      expect(orders.items.single.lines.single.options, ['Queso']);
      await tester.tap(find.text('Pedido entregado'));
      await tester.pumpAndSettle();
      expect(orders.items.single.status, OrderStatus.delivered);
      await tester.tap(find.text('Entregados'));
      await tester.pumpAndSettle();
      expect(find.text('Carlos Mendoza'), findsOneWidget);
      await tester.tap(find.text('Aún pendiente'));
      await tester.pumpAndSettle();
      expect(orders.items.single.status, OrderStatus.pending);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('delivery time can be selected, retained, cancelled and reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orders = FakeOrders();
    addTearDown(orders.changes.close);
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          auth: FakeAuth(user: const AppUser('alice', 'Ana')),
          orders: orders,
          catalog: FakeCatalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Lo antes posible'), findsOneWidget);
    final field = find.byKey(const ValueKey('deliveryTimeField'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(TimePickerDialog)),
    ).pop(const TimeOfDay(hour: 14, minute: 30));
    await tester.pumpAndSettle();
    expect(find.text('Lo antes posible'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Customer');
    await tester.enterText(find.byType(TextFormField).at(1), 'Address');
    await tester.tap(find.byTooltip('Agregar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar pedido'));
    await tester.tap(find.text('Guardar pedido'));
    await tester.pumpAndSettle();
    expect(orders.items.single.deliveryTimeMinutes, 870);
    await tester.tap(find.text('Editar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 14, minute: 30),
    );
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Lo antes posible'), findsNothing);
    await tester.tap(find.byTooltip('Lo antes posible'));
    await tester.pumpAndSettle();
    expect(find.text('Lo antes posible'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar pedido'));
    await tester.tap(find.text('Guardar pedido'));
    await tester.pumpAndSettle();
    expect(orders.items.single.deliveryTimeMinutes, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings change locale and add a catalog item', (tester) async {
    final catalog = FakeCatalog();
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          auth: FakeAuth(user: const AppUser('alice', 'Ana')),
          orders: FakeOrders(),
          catalog: catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Solo hamburguesa',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '3,50');
    await tester.enterText(find.byType(TextFormField).at(2), 'Cebolla, Queso');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(catalog.items.last.priceCents, 350);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('another user edits a delivered order and confirms deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orders = FakeOrders();
    addTearDown(orders.changes.close);
    final created = DateTime(2026, 9, 1), delivered = DateTime(2026, 9, 2);
    orders.items.add(
      CustomerOrder(
        id: 'existing',
        name: 'Carlos',
        address: 'Old address',
        creator: const AppUser('alice', 'Ana'),
        status: OrderStatus.delivered,
        createdAt: created,
        deliveredAt: delivered,
        lines: [
          OrderLine(
            itemId: 'burger',
            name: 'Original burger',
            priceCents: 550,
            quantity: 1,
            options: ['Queso'],
          ),
        ],
      ),
    );
    final catalog = FakeCatalog()
      ..items = [
        MenuItem(
          id: 'burger',
          name: 'Changed burger',
          priceCents: 900,
          active: false,
        ),
      ];
    await tester.pumpWidget(
      OrdersApp(
        services: AppServices(
          auth: FakeAuth(user: const AppUser('bob', 'Bob')),
          orders: orders,
          catalog: catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Original burger'), findsWidgets);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Carlos actualizado',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'New address');
    await tester.tap(find.byTooltip('Agregar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar pedido'));
    await tester.tap(find.text('Guardar pedido'));
    await tester.pumpAndSettle();
    final updated = orders.items.single;
    expect(updated.name, 'Carlos actualizado');
    expect(updated.address, 'New address');
    expect(updated.totalCents, 1100);
    expect(updated.lines.single.options, ['Queso']);
    expect(updated.creator.id, 'alice');
    expect(updated.createdAt, created);
    expect(updated.deliveredAt, delivered);
    expect(updated.status, OrderStatus.delivered);
    await tester.tap(find.byTooltip('Eliminar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(orders.items, hasLength(1));
    await tester.tap(find.byTooltip('Eliminar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(orders.items, isEmpty);
    expect(find.text('Aún no hay entregas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
