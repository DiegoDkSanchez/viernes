import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../orders/domain/orders.dart';
import '../domain/daily_revenue.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key, required this.orders});
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final days = dailyRevenue(orders);
    if (days.isEmpty) {
      return EmptyState(
        title: s.t('emptyAnalytics'),
        subtitle: s.t('analyticsHint'),
        icon: Icons.bar_chart,
      );
    }
    final dateFormat = DateFormat.yMMMd(s.locale.toLanguageTag());
    final shortDate = DateFormat.MMMd(s.locale.toLanguageTag());
    final maximum = days.fold<int>(
      0,
      (max, day) => day.totalCents > max ? day.totalCents : max,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('dailyRevenue'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(s.t('analyticsHint')),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('deliveredRevenue')),
                      Text(
                        s.money(
                          days.fold<int>(0, (sum, day) => sum + day.totalCents),
                        ),
                        key: const ValueKey('analyticsTotal'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(s.t('chartHint')),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final day = days[i];
                            return Semantics(
                              label:
                                  '${dateFormat.format(day.date)}: ${s.money(day.totalCents)}',
                              child: SizedBox(
                                width: 100,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 32,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(s.money(day.totalCents)),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 152,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: 44,
                                          height: maximum == 0
                                              ? 0
                                              : 152 * day.totalCents / maximum,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(shortDate.format(day.date)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.t('byDeliveryDate'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
            ],
          );
        }
        final day = days[index - 1];
        return Card(
          child: ListTile(
            title: Text(dateFormat.format(day.date)),
            trailing: Text(
              s.money(day.totalCents),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      },
    );
  }
}
