import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/sale_day.dart';

class FirestoreAnalyticsRepository implements AnalyticsRepository {
  FirestoreAnalyticsRepository(FirebaseFirestore db)
    : _days = db.collection('shops/main/saleDays');
  final CollectionReference<Map<String, dynamic>> _days;
  CollectionReference<Map<String, dynamic>> _expenses(DateTime date) =>
      _days.doc(saleDayId(date)).collection('expenses');

  @override
  Stream<List<DateTime>> watchDays() => _days
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final utc = (doc.data()['date'] as Timestamp).toDate().toUtc();
          return calendarDate(utc);
        }).toList(),
      );

  @override
  Future<void> addDay(DateTime date) => _days.doc(saleDayId(date)).set({
    // UTC midnight encodes a calendar date, not a moment in the device timezone.
    'date': Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day)),
  });

  @override
  Stream<List<Expense>> watchExpenses(DateTime date) =>
      _expenses(date).snapshots().map((snapshot) {
        final expenses =
            snapshot.docs
                .map(
                  (doc) => Expense(
                    id: doc.id,
                    name: doc.data()['name'] as String,
                    amountCents: doc.data()['amountCents'] as int,
                  ),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return expenses;
      });

  @override
  String newExpenseId(DateTime date) => _expenses(date).doc().id;
  @override
  Future<void> saveExpense(DateTime date, Expense expense) {
    validateExpense(expense);
    return _expenses(date).doc(expense.id).set({
      'name': expense.name.trim(),
      'amountCents': expense.amountCents,
    });
  }

  @override
  Future<void> deleteExpense(DateTime date, String id) =>
      _expenses(date).doc(id).delete();
}
