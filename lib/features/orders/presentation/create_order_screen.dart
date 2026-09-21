import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../auth/domain/auth_repository.dart';
import '../../catalog/domain/catalog.dart';
import '../domain/orders.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.services,
    required this.user,
    this.order,
  });
  final AppServices services;
  final AppUser user;
  final CustomerOrder? order;
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), address = TextEditingController();
  final Map<String, int> quantities = {};
  final Map<String, Set<String>> selected = {};
  late Stream<List<MenuItem>> menu;
  late final String id;
  bool saving = false;
  TimeOfDay? deliveryTime;
  @override
  void initState() {
    super.initState();
    menu = widget.services.watchMenu();
    id = widget.order?.id ?? widget.services.orders.newId();
    final order = widget.order;
    if (order != null) {
      final minutes = order.deliveryTimeMinutes;
      if (minutes != null) {
        deliveryTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      }
      name.text = order.name;
      address.text = order.address;
      for (final line in order.lines) {
        quantities[line.itemId] = line.quantity;
        selected[line.itemId] = line.options.toSet();
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  List<MenuItem> editableMenu(List<MenuItem> catalog) {
    final items = {
      for (final item in catalog.where((i) => i.active)) item.id: item,
    };
    // Existing products keep their saved price/name/options, even if deactivated.
    for (final line in widget.order?.lines ?? <OrderLine>[]) {
      items[line.itemId] = MenuItem(
        id: line.itemId,
        name: line.name,
        priceCents: line.priceCents,
        options: {...line.options, ...?items[line.itemId]?.options}.toList(),
      );
    }
    return items.values.toList();
  }

  List<OrderLine> lines(List<MenuItem> items) => items
      .where((i) => i.active && (quantities[i.id] ?? 0) > 0)
      .map(
        (i) => OrderLine.fromMenu(
          i,
          quantities[i.id]!,
          (selected[i.id] ?? {}).where(i.options.contains).toList(),
        ),
      )
      .toList();
  Future<void> save(List<OrderLine> orderLines) async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final order = CustomerOrder(
        id: id,
        name: name.text.trim(),
        address: address.text.trim(),
        lines: orderLines,
        creator: widget.order?.creator ?? widget.user,
        status: widget.order?.status ?? OrderStatus.pending,
        createdAt: widget.order?.createdAt,
        deliveredAt: widget.order?.deliveredAt,
        deliveryTimeMinutes: deliveryTime == null
            ? null
            : deliveryTime!.hour * 60 + deliveryTime!.minute,
      );
      if (widget.order == null) {
        await widget.services.createOrder(order);
      } else {
        await widget.services.updateOrder(order);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickDeliveryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: deliveryTime ?? TimeOfDay.now(),
      helpText: Strings.of(context).t('deliveryTime'),
    );
    if (mounted && picked != null) {
      setState(() => deliveryTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t(widget.order == null ? 'newOrder' : 'editOrder')),
          centerTitle: true,
        ),
        body: PageWidth(
          child: StreamBuilder<List<MenuItem>>(
            stream: menu,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  error: snapshot.error!,
                  retry: () =>
                      setState(() => menu = widget.services.watchMenu()),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = editableMenu(snapshot.data!);
              final orderLines = lines(items);
              final total = orderLines.fold(0, (sum, l) => sum + l.totalCents);
              return AbsorbPointer(
                absorbing: saving,
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextFormField(
                        controller: name,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: s.t('name'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? s.t('required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: address,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: s.t('address'),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? s.t('required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        key: const ValueKey('deliveryTimeField'),
                        onTap: pickDeliveryTime,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: s.t('deliveryTime'),
                            prefixIcon: const Icon(Icons.schedule),
                            suffixIcon: deliveryTime == null
                                ? const Icon(Icons.arrow_drop_down)
                                : IconButton(
                                    tooltip: s.t('asSoonAsPossible'),
                                    onPressed: () =>
                                        setState(() => deliveryTime = null),
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                          child: Text(
                            deliveryTime?.format(context) ??
                                s.t('asSoonAsPossible'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '🍔  ${s.t('menu')}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      if (items.isEmpty)
                        EmptyState(
                          title: s.t('emptyMenu'),
                          subtitle: s.t('emptyMenuHint'),
                        ),
                      for (final item in items)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '🍔',
                                      style: TextStyle(fontSize: 36),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          Text(
                                            s.money(item.priceCents),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton.filledTonal(
                                      tooltip: s.t('remove'),
                                      onPressed: (quantities[item.id] ?? 0) == 0
                                          ? null
                                          : () => setState(
                                              () => quantities[item.id] =
                                                  quantities[item.id]! - 1,
                                            ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Semantics(
                                      label: s.t('quantity'),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          '${quantities[item.id] ?? 0}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      tooltip: s.t('add'),
                                      onPressed:
                                          (quantities[item.id] ?? 0) >= 99
                                          ? null
                                          : () {
                                              if ((quantities[item.id] ?? 0) ==
                                                      0 &&
                                                  orderLines.length >= 4) {
                                                showError(
                                                  context,
                                                  const FormatException(
                                                    'maxItems',
                                                  ),
                                                );
                                                return;
                                              }
                                              setState(
                                                () => quantities[item.id] =
                                                    (quantities[item.id] ?? 0) +
                                                    1,
                                              );
                                            },
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                if ((quantities[item.id] ?? 0) > 0 &&
                                    item.options.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      for (final option in item.options)
                                        FilterChip(
                                          label: Text(option),
                                          selected:
                                              selected[item.id]?.contains(
                                                option,
                                              ) ??
                                              false,
                                          onSelected: (value) => setState(() {
                                            final options = selected
                                                .putIfAbsent(
                                                  item.id,
                                                  () => <String>{},
                                                );
                                            value
                                                ? options.add(option)
                                                : options.remove(option);
                                          }),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('summary'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 14),
                            for (final line in orderLines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${line.name} ×${line.quantity}${line.options.isEmpty ? '' : '\n${line.options.join(', ')}'}',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(s.money(line.totalCents)),
                                  ],
                                ),
                              ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.t('total'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  s.money(total),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: saving || orderLines.isEmpty
                            ? null
                            : () => save(orderLines),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(s.t('saveOrder')),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
