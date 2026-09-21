import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../l10n/strings.dart';

String errorText(BuildContext context, Object error) {
  final s = Strings.of(context);
  if (error is FormatException) return s.t(error.message);
  if (error is FirebaseException && error.code == 'permission-denied') {
    return s.t('access');
  }
  return s.t('error');
}

void showError(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(errorText(context, error))));

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.receipt_long_outlined,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(errorText(context, error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: retry,
            child: Text(Strings.of(context).t('retry')),
          ),
        ],
      ),
    ),
  );
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: child,
    ),
  );
}
