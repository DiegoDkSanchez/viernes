import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_services.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/orders/presentation/orders_screen.dart';
import 'l10n/strings.dart';

class OrdersApp extends StatefulWidget {
  const OrdersApp({super.key, this.services});
  final AppServices? services;
  @override
  State<OrdersApp> createState() => _OrdersAppState();
}

class _OrdersAppState extends State<OrdersApp> {
  Locale locale = const Locale('es');
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Burger Pedidos',
    theme: appTheme(),
    locale: locale,
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: widget.services == null
        ? Builder(
            builder: (context) => Scaffold(
              body: EmptyState(
                title: Strings.of(context).t('brand'),
                subtitle: Strings.of(context).t('setup'),
                icon: Icons.cloud_off,
              ),
            ),
          )
        : AuthGate(
            services: widget.services!,
            setLocale: (value) => setState(() => locale = value),
          ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.services, required this.setLocale});
  final AppServices services;
  final ValueChanged<Locale> setLocale;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<AppUser?> stream = widget.services.auth.watchUser();
  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: ErrorState(
            error: snapshot.error!,
            retry: () =>
                setState(() => stream = widget.services.auth.watchUser()),
          ),
        );
      }
      if (snapshot.data == null) return LoginScreen(services: widget.services);
      return OrdersScreen(
        key: ValueKey(snapshot.data!.id),
        services: widget.services,
        user: snapshot.data!,
        setLocale: widget.setLocale,
      );
    },
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍔', style: TextStyle(fontSize: 90)),
                  const SizedBox(height: 24),
                  Text(
                    s.t('brand'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t('tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(s.t('loginHint'), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                await widget.services.signIn();
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(s.t('login')),
                    ),
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
