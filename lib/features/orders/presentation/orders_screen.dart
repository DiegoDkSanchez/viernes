import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../auth/domain/auth_repository.dart';
import '../../analytics/presentation/analytics_view.dart';
import '../../catalog/presentation/settings_screen.dart';
import '../domain/orders.dart';
import 'create_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.services,
    required this.user,
    required this.setLocale,
  });
  final AppServices services;
  final AppUser user;
  final ValueChanged<Locale> setLocale;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int index = 0;
  late Stream<List<CustomerOrder>> stream;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    stream = widget.services.watchOrders(
      index == 0 ? OrderStatus.pending : OrderStatus.delivered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('brand')),
        actions: [
          IconButton(
            tooltip: s.t('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  services: widget.services,
                  user: widget.user,
                  setLocale: widget.setLocale,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageWidth(
        child: StreamBuilder<List<CustomerOrder>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                error: snapshot.error!,
                retry: () => setState(reload),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!;
            if (index == 2) return AnalyticsView(orders: orders);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t(index == 0 ? 'pendingTitle' : 'deliveredTitle'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${orders.length} ${s.t(index == 0 ? 'waiting' : 'completed')}',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? EmptyState(
                          title: s.t(index == 0 ? 'emptyPending' : 'emptyDone'),
                          subtitle: s.t(
                            index == 0 ? 'emptyPendingHint' : 'emptyDoneHint',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: orders.length,
                          itemBuilder: (_, i) => OrderCard(
                            key: ValueKey(orders[i].id),
                            order: orders[i],
                            services: widget.services,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateOrderScreen(
                    services: widget.services,
                    user: widget.user,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(s.t('newOrder')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() {
          index = value;
          reload();
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            label: s.t('pending'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: const Icon(Icons.check_circle, color: green),
            label: s.t('delivered'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: s.t('analytics'),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatefulWidget {
  const OrderCard({super.key, required this.order, required this.services});
  final CustomerOrder order;
  final AppServices services;
  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool busy = false;
  Future<void> change() async {
    setState(() => busy = true);
    try {
      if (widget.order.status == OrderStatus.pending) {
        await widget.services.deliver(widget.order.id);
      } else {
        await widget.services.reopen(widget.order.id);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final s = Strings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('deleteOrder')),
        content: Text(s.t('deleteOrderConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.services.deleteOrder(widget.order.id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context), o = widget.order;
    final done = o.status == OrderStatus.delivered;
    final initials = o.name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDCE9F2),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text('⌖ ${o.address}'),
                      const SizedBox(height: 3),
                      Text(
                        '${s.t('deliveryTime')}: ${o.deliveryTimeMinutes == null ? s.t('asSoonAsPossible') : TimeOfDay(hour: o.deliveryTimeMinutes! ~/ 60, minute: o.deliveryTimeMinutes! % 60).format(context)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFFE0F4E8)
                        : const Color(0xFFFFEEDC),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    s.t(done ? 'deliveredBadge' : 'pendingBadge'),
                    style: TextStyle(
                      fontSize: 12,
                      color: done ? green : orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🍔', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in o.lines) ...[
                        Row(
                          children: [
                            Text('${line.quantity}', style: TextStyle(fontSize: 30),),
                            Text('× ${line.name}'),
                          ],
                        ),
                        if (line.options.isNotEmpty)
                          Text(
                            line.options.join(', '),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${s.t('total')}: ${s.money(o.totalCents)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${s.t('creator')}: ${o.creator.name}',
              style: const TextStyle(fontSize: 12),
            ),
            if ((done ? o.deliveredAt : o.createdAt) != null)
              Text(
                s.date((done ? o.deliveredAt : o.createdAt)!),
                style: const TextStyle(fontSize: 12),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreateOrderScreen(
                              services: widget.services,
                              user: o.creator,
                              order: o,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.t('editOrder')),
                ),
                IconButton(
                  tooltip: s.t('deleteOrder'),
                  onPressed: busy ? null : delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: done
                  ? OutlinedButton.icon(
                      onPressed: busy ? null : change,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(s.t('reopen')),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: busy ? null : change,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(s.t('deliver')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
