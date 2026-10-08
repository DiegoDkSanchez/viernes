import '../../orders/domain/orders.dart';

DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);
String saleDayId(DateTime date) => '${date.year}-${date.month}-${date.day}';

class Expense {
  const Expense({
    required this.id,
    required this.name,
    required this.amountCents,
  });
  final String id;
  final String name;
  final int amountCents;
}

abstract interface class AnalyticsRepository {
  Stream<List<DateTime>> watchDays();
  Future<void> addDay(DateTime date);
  Stream<List<Expense>> watchExpenses(DateTime date);
  String newExpenseId(DateTime date);
  Future<void> saveExpense(DateTime date, Expense expense);
  Future<void> deleteExpense(DateTime date, String id);
}

void validateExpense(Expense expense) {
  if (expense.name.trim().isEmpty ||
      expense.name.trim().length > 100 ||
      expense.amountCents < 1 ||
      expense.amountCents > 1000000) {
    throw const FormatException('invalidExpense');
  }
}

class SaleDaySummary {
  SaleDaySummary(
    DateTime date,
    Iterable<CustomerOrder> orders,
    Iterable<Expense> expenses,
  ) {
    for (final order in orders) {
      if (order.status == OrderStatus.delivered &&
          order.deliveredAt != null &&
          calendarDate(order.deliveredAt!.toLocal()) == calendarDate(date)) {
        salesCents += order.totalCents;
        orderCount++;
      }
    }
    expensesCents = expenses.fold(
      0,
      (sum, expense) => sum + expense.amountCents,
    );
  }
  int salesCents = 0;
  int orderCount = 0;
  late final int expensesCents;
  int get profitCents => salesCents - expensesCents;
}
