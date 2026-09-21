import '../../orders/domain/orders.dart';

class DailyRevenue {
  const DailyRevenue(this.date, this.totalCents);
  final DateTime date;
  final int totalCents;
}

/// Delivery-day revenue in the device's local timezone, newest day first.
List<DailyRevenue> dailyRevenue(Iterable<CustomerOrder> orders) {
  final totals = <DateTime, int>{};
  for (final order in orders) {
    if (order.status != OrderStatus.delivered || order.deliveredAt == null) {
      continue;
    }
    final delivered = order.deliveredAt!.toLocal();
    final day = DateTime(delivered.year, delivered.month, delivered.day);
    totals.update(
      day,
      (total) => total + order.totalCents,
      ifAbsent: () => order.totalCents,
    );
  }
  final dates = totals.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in dates) DailyRevenue(day, totals[day]!)];
}
