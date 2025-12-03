import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';

/// Screen shown when user cancels Stripe checkout
class CheckoutCanceledScreen extends ConsumerWidget {
  const CheckoutCanceledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingPlan = ref.watch(pendingUpgradePlanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Canceled'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 100,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  'Checkout Canceled',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your checkout was canceled. No charges were made to your account.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    if (pendingPlan != null) {
                      context.go('/upgrade?plan=$pendingPlan');
                    } else {
                      context.go('/settings');
                    }
                  },
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
