import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../domain/sale_day.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.date,
    required this.repository,
  });
  final DateTime date;
  final AnalyticsRepository repository;
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Stream<List<Expense>> stream = widget.repository.watchExpenses(
    widget.date,
  );
  final deleting = <String>{};
  Future<void> delete(Expense expense) async {
    setState(() => deleting.add(expense.id));
    try {
      await widget.repository.deleteExpense(widget.date, expense.id);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => deleting.remove(expense.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('expenses')),
        actions: [
          IconButton(
            tooltip: s.t('addExpense'),
            icon: const Icon(Icons.add),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ExpenseDialog(
                date: widget.date,
                repository: widget.repository,
              ),
            ),
          ),
        ],
      ),
      body: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                DateFormat.yMMMMd(s.locale.toLanguageTag()).format(widget.date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Expense>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      retry: () => setState(
                        () => stream = widget.repository.watchExpenses(
                          widget.date,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return EmptyState(
                      title: s.t('noExpenses'),
                      subtitle: s.t('expenseEmptyHint'),
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(s.money(item.amountCents)),
                          trailing: IconButton(
                            tooltip: s.t('delete'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: deleting.contains(item.id)
                                ? null
                                : () => delete(item),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.date, required this.repository});
  final DateTime date;
  final AnalyticsRepository repository;
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final amount = TextEditingController();
  late final id = widget.repository.newExpenseId(widget.date);
  bool busy = false;
  int? get cents {
    final text = amount.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final value =
        int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return value >= 1 && value <= 1000000 ? value : null;
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final expense = Expense(
      id: id,
      name: name.text.trim(),
      amountCents: cents!,
    );
    setState(() => busy = true);
    try {
      await widget.repository.saveExpense(widget.date, expense);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(s.t('addExpense')),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: s.t('expenseName')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? s.t('required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: s.t('amount')),
                  validator: (_) => cents == null ? s.t('invalidPrice') : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel')),
          ),
          FilledButton(onPressed: busy ? null : save, child: Text(s.t('save'))),
        ],
      ),
    );
  }
}
