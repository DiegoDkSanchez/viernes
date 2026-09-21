import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/auth/domain/auth_repository.dart';
import 'package:viernes/features/catalog/domain/catalog.dart';
import 'package:viernes/features/orders/domain/orders.dart';
import 'package:viernes/l10n/strings.dart';
import 'fakes.dart';

void main() {
  test(
    'order total uses integer cents and preserves price snapshots',
    () async {
      final repo = FakeOrders();
      final item = MenuItem(
        id: 'one',
        name: 'Burger',
        priceCents: 550,
        options: ['Cheese'],
      );
      final order = CustomerOrder(
        id: 'a',
        name: 'Customer',
        address: 'Street',
        creator: const AppUser('u', 'Ana'),
        lines: [
          OrderLine.fromMenu(item, 2, ['Cheese']),
          OrderLine(
            itemId: 'two',
            name: 'Burger',
            priceCents: 350,
            quantity: 1,
          ),
        ],
      );
      await CreateOrder(repo)(order);
      expect(order.totalCents, 1450);
      expect(() => order.lines.clear(), throwsUnsupportedError);
    },
  );
  test('empty orders and invalid quantities never reach repository', () {
    final repo = FakeOrders();
    for (final lines in <List<OrderLine>>[
      [],
      [OrderLine(itemId: 'x', name: 'Burger', priceCents: 1, quantity: 0)],
    ]) {
      expect(
        () => CreateOrder(repo)(
          CustomerOrder(
            id: 'a',
            name: 'A',
            address: 'B',
            creator: const AppUser('u', 'A'),
            lines: lines,
          ),
        ),
        throwsFormatException,
      );
    }
    expect(repo.items, isEmpty);
  });
  test('unknown options and inactive products cannot be ordered', () {
    expect(
      () => OrderLine.fromMenu(
        MenuItem(id: 'x', name: 'A', priceCents: 100),
        1,
        ['unknown'],
      ),
      throwsFormatException,
    );
    expect(
      () => OrderLine.fromMenu(
        MenuItem(id: 'x', name: 'A', priceCents: 100, active: false),
        1,
        [],
      ),
      throwsFormatException,
    );
  });
  test('menu validation rejects duplicate options and negative prices', () {
    final save = SaveMenuItem(FakeCatalog());
    expect(
      () => save(MenuItem(id: 'x', name: 'A', priceCents: -1)),
      throwsFormatException,
    );
    expect(
      () => save(
        MenuItem(id: 'x', name: 'A', priceCents: 100, options: ['A', 'A']),
      ),
      throwsFormatException,
    );
  });
  test('Spanish and English cover exactly the same UI messages', () {
    expect(Strings.es.keys.toSet(), Strings.en.keys.toSet());
  });
}
