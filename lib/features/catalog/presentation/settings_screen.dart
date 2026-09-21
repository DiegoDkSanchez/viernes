import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/widgets.dart';
import '../../../l10n/strings.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/catalog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    required this.user,
    required this.setLocale,
  });
  final AppServices services;
  final AppUser user;
  final ValueChanged<Locale> setLocale;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Stream<List<MenuItem>> stream;
  bool signingOut = false;
  @override
  void initState() {
    super.initState();
    stream = widget.services.watchMenu();
  }

  void edit([MenuItem? item]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MenuEditor(services: widget.services, item: item),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: PageWidth(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(widget.user.name),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Text(s.t('language'))),
                  DropdownButton<String>(
                    value: s.locale.languageCode,
                    items: const [
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) widget.setLocale(Locale(value));
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('menu'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.add),
                    label: Text(s.t('addItem')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<MenuItem>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error!,
                      retry: () =>
                          setState(() => stream = widget.services.watchMenu()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return EmptyState(
                      title: s.t('emptyMenu'),
                      subtitle: s.t('emptyMenuHint'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (_, i) {
                      final item = snapshot.data![i];
                      return Card(
                        child: ListTile(
                          onTap: () => edit(item),
                          leading: const Text(
                            '🍔',
                            style: TextStyle(fontSize: 30),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${s.money(item.priceCents)}${item.active ? '' : ' · ${s.t('unavailable')}'}\n${item.options.join(', ')}',
                          ),
                          isThreeLine: item.options.isNotEmpty,
                          trailing: IconButton(
                            tooltip: s.t('editItem'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => edit(item),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: signingOut
                      ? null
                      : () async {
                          setState(() => signingOut = true);
                          try {
                            await widget.services.signOut();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          } finally {
                            if (mounted) setState(() => signingOut = false);
                          }
                        },
                  icon: const Icon(Icons.logout),
                  label: Text(s.t('logout')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuEditor extends StatefulWidget {
  const MenuEditor({super.key, required this.services, this.item});
  final AppServices services;
  final MenuItem? item;
  @override
  State<MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends State<MenuEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, price, options;
  late bool active;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.item?.name);
    price = TextEditingController(
      text: widget.item == null
          ? ''
          : (widget.item!.priceCents / 100).toStringAsFixed(2),
    );
    options = TextEditingController(text: widget.item?.options.join(', '));
    active = widget.item?.active ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    options.dispose();
    super.dispose();
  }

  int? parsePrice() {
    final text = price.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.services.saveMenu(
        MenuItem(
          id: widget.item?.id ?? '',
          name: name.text.trim(),
          priceCents: parsePrice()!,
          options: options.text
              .split(',')
              .map((o) => o.trim())
              .where((o) => o.isNotEmpty)
              .toList(),
          active: active,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t(widget.item == null ? 'addItem' : 'editItem')),
        ),
        body: PageWidth(
          child: AbsorbPointer(
            absorbing: saving,
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: name,
                    maxLength: 100,
                    decoration: InputDecoration(labelText: s.t('itemName')),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? s.t('required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: s.t('price')),
                    validator: (_) {
                      final p = parsePrice();
                      return p == null || p < 1 || p > 1000000
                          ? s.t('invalidPrice')
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: options,
                    maxLength: 414,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: s.t('options'),
                      hintText: s.t('optionsHint'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.t('active')),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(s.t('save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
