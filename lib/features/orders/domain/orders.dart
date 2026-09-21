import '../../auth/domain/auth_repository.dart';
import '../../catalog/domain/catalog.dart';

enum OrderStatus { pending, delivered }

class OrderLine {
  OrderLine({
    required this.itemId,
    required this.name,
    required this.priceCents,
    required this.quantity,
    List<String> options = const [],
  }) : options = List.unmodifiable(options);
  factory OrderLine.fromMenu(
    MenuItem item,
    int quantity,
    List<String> options,
  ) {
    if (!item.active || options.any((o) => !item.options.contains(o))) {
      throw const FormatException('invalidOrder');
    }
    return OrderLine(
      itemId: item.id,
      name: item.name,
      priceCents: item.priceCents,
      quantity: quantity,
      options: options,
    );
  }
  final String itemId;
  final String name;
  final int priceCents;
  final int quantity;
  final List<String> options;
  int get totalCents => priceCents * quantity;
}

class CustomerOrder {
  CustomerOrder({
    required this.id,
    required this.name,
    required this.address,
    required List<OrderLine> lines,
    required this.creator,
    this.status = OrderStatus.pending,
    this.createdAt,
    this.deliveredAt,
    this.deliveryTimeMinutes,
  }) : lines = List.unmodifiable(lines);
  final String id;
  final String name;
  final String address;
  final List<OrderLine> lines;
  final AppUser creator;
  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? deliveredAt;

  /// Local clock minutes since midnight; null means as soon as possible.
  final int? deliveryTimeMinutes;
  int get totalCents => lines.fold(0, (sum, line) => sum + line.totalCents);
}

abstract interface class OrderRepository {
  Stream<List<CustomerOrder>> watchOrders(OrderStatus status);
  String newId();
  Future<void> create(CustomerOrder order);
  Future<void> setStatus(String id, OrderStatus status);
  Future<void> update(CustomerOrder order);
  Future<void> delete(String id);
}

class CreateOrder {
  const CreateOrder(this.repository);
  final OrderRepository repository;
  Future<void> call(CustomerOrder order) {
    validateOrder(order);
    if (order.status != OrderStatus.pending) {
      throw const FormatException('invalidOrder');
    }
    return repository.create(order);
  }
}

class WatchOrders {
  const WatchOrders(this.repository);
  final OrderRepository repository;
  Stream<List<CustomerOrder>> call(OrderStatus status) =>
      repository.watchOrders(status);
}

class MarkOrderDelivered {
  const MarkOrderDelivered(this.repository);
  final OrderRepository repository;
  Future<void> call(String id) =>
      repository.setStatus(id, OrderStatus.delivered);
}

class ReopenOrder {
  const ReopenOrder(this.repository);
  final OrderRepository repository;
  Future<void> call(String id) => repository.setStatus(id, OrderStatus.pending);
}

void validateOrder(CustomerOrder order) {
  if (order.name.trim().isEmpty ||
      order.name.length > 100 ||
      order.address.trim().isEmpty ||
      order.address.length > 300 ||
      order.creator.id.isEmpty ||
      (order.deliveryTimeMinutes != null &&
          (order.deliveryTimeMinutes! < 0 ||
              order.deliveryTimeMinutes! >= 1440)) ||
      order.lines.isEmpty ||
      order.lines.length > 4 ||
      order.lines.any(
        (l) =>
            l.quantity < 1 ||
            l.quantity > 99 ||
            l.priceCents < 1 ||
            l.priceCents > 1000000 ||
            l.name.isEmpty ||
            l.name.length > 100 ||
            l.options.length > 8 ||
            l.options.toSet().length != l.options.length ||
            l.options.any((o) => o.isEmpty || o.length > 50),
      )) {
    throw const FormatException('invalidOrder');
  }
}

class UpdateOrder {
  const UpdateOrder(this.repository);
  final OrderRepository repository;
  Future<void> call(CustomerOrder order) {
    validateOrder(order);
    return repository.update(order);
  }
}

class DeleteOrder {
  const DeleteOrder(this.repository);
  final OrderRepository repository;
  Future<void> call(String id) => repository.delete(id);
}
