import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../orders/domain/orders.dart';
import '../domain/sale_day.dart';
import 'expenses_screen.dart';
import 'sold_items_screen.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({
    super.key,
    required this.orders,
    required this.repository,
    required this.watchOrders,
  });
  final List<CustomerOrder> orders;
  final AnalyticsRepository repository;
  final WatchOrders watchOrders;
  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  late Stream<List<DateTime>> days = widget.repository.watchDays();
  DateTime? selected;
  bool busy = false;

  Future<void> addDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selected ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repository.addDay(date);
      if (mounted) setState(() => selected = date);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return StreamBuilder<List<DateTime>>(
      stream: days,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            error: snapshot.error!,
            retry: () => setState(() => days = widget.repository.watchDays()),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dates = snapshot.data!;
        final date = dates.contains(selected) ? selected : dates.firstOrNull;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: dates.isEmpty
                        ? Text(
                            s.t('saleDay'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              key: const ValueKey('saleDaySelector'),
                              isExpanded: true,
                              value: date,
                              style: Theme.of(context).textTheme.titleLarge,
                              items: [
                                for (final day in dates)
                                  DropdownMenuItem(
                                    value: day,
                                    child: Text(
                                      DateFormat.yMMMd(
                                        s.locale.toLanguageTag(),
                                      ).format(day),
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => selected = value),
                            ),
                          ),
                  ),
                  IconButton.filledTonal(
                    tooltip: s.t('addDate'),
                    onPressed: busy ? null : addDate,
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: date == null
                  ? EmptyState(
                      title: s.t('noSaleDays'),
                      subtitle: s.t('saleDayHint'),
                      icon: Icons.event_outlined,
                    )
                  : _DayCards(
                      key: ValueKey(date),
                      date: date,
                      orders: widget.orders,
                      watchOrders: widget.watchOrders,
                      repository: widget.repository,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DayCards extends StatefulWidget {
  const _DayCards({
    super.key,
    required this.date,
    required this.orders,
    required this.repository,
    required this.watchOrders,
  });
  final DateTime date;
  final List<CustomerOrder> orders;
  final AnalyticsRepository repository;
  final WatchOrders watchOrders;
  @override
  State<_DayCards> createState() => _DayCardsState();
}

class _DayCardsState extends State<_DayCards> {
  late Stream<List<Expense>> stream = widget.repository.watchExpenses(
    widget.date,
  );
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<Expense>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            error: snapshot.error!,
            retry: () => setState(
              () => stream = widget.repository.watchExpenses(widget.date),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = SaleDaySummary(
          widget.date,
          widget.orders,
          snapshot.data!,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _MetricCard(
              title: s.t('expenses'),
              value: s.money(summary.expensesCents),
              icon: Icons.receipt_long_outlined,
              hint: s.t('expenseHint'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExpensesScreen(
                    date: widget.date,
                    repository: widget.repository,
                  ),
                ),
              ),
            ),
            _MetricCard(
              title: s.t('sales'),
              value: s.money(summary.salesCents),
              valueKey: const ValueKey('analyticsTotal'),
              icon: Icons.payments_outlined,
            ),
            _MetricCard(
              title: s.t('orderCount'),
              value: '${summary.orderCount}',
              hint: s.t('soldItemsHint'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SoldItemsScreen(
                    date: widget.date,
                    watchOrders: widget.watchOrders,
                  ),
                ),
              ),
              icon: Icons.shopping_bag_outlined,
            ),
            _MetricCard(
              title: s.t('profits'),
              value: s.money(summary.profitCents),
              valueKey: const ValueKey('analyticsProfit'),
              icon: Icons.account_balance_wallet_outlined,
              hint: s.t('profitHint'),
              color: summary.profitCents < 0
                  ? colors.errorContainer
                  : colors.primaryContainer,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                s.t('analyticsHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.hint,
    this.onTap,
    this.color,
    this.valueKey,
  });
  final String title, value;
  final IconData icon;
  final String? hint;
  final VoidCallback? onTap;
  final Color? color;
  final Key? valueKey;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    key: valueKey,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (hint != null) ...[const SizedBox(height: 4), Text(hint!)],
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
