import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../orders/domain/orders.dart';
import '../domain/sale_day.dart';

class SoldItemsScreen extends StatefulWidget {
  const SoldItemsScreen({
    super.key,
    required this.date,
    required this.watchOrders,
  });
  final DateTime date;
  final WatchOrders watchOrders;

  @override
  State<SoldItemsScreen> createState() => _SoldItemsScreenState();
}

class _SoldItemsScreenState extends State<SoldItemsScreen> {
  late Stream<List<CustomerOrder>> stream = widget.watchOrders(
    OrderStatus.delivered,
  );

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('soldItems'))),
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
              child: StreamBuilder<List<CustomerOrder>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      retry: () => setState(
                        () =>
                            stream = widget.watchOrders(OrderStatus.delivered),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final summary = SaleDaySummary(
                    widget.date,
                    snapshot.data!,
                    const [],
                  );
                  final items = summary.soldItems;
                  if (items.isEmpty) {
                    return EmptyState(
                      title: s.t('noSoldItems'),
                      subtitle: s.t('noSoldItemsHint'),
                      icon: Icons.shopping_bag_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          title: Text(s.t('totalItemsSold')),
                          trailing: Text(
                            '${summary.itemCount}',
                            key: const ValueKey('soldItemsTotal'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        );
                      }
                      final item = items[index - 1];
                      return ListTile(
                        key: ValueKey('soldItem-${item.itemId}'),
                        title: Text(item.name),
                        trailing: Text(
                          '${item.quantity}',
                          style: Theme.of(context).textTheme.titleLarge,
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
