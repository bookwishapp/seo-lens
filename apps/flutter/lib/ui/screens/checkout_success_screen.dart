import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';

/// Screen shown after successful Stripe checkout
class CheckoutSuccessScreen extends ConsumerStatefulWidget {
  const CheckoutSuccessScreen({super.key});

  @override
  ConsumerState<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends ConsumerState<CheckoutSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Invalidate profile to refresh plan information
    Future.delayed(Duration.zero, () {
      ref.invalidate(currentProfileProvider);
      _checkOnboardingStatus();
    });
  }

  Future<void> _checkOnboardingStatus() async {
    // Wait a moment for profile to refresh
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if user has domains
    final domains = await ref.read(domainsProvider.future);

    if (mounted && domains.isEmpty) {
      // New user - redirect to onboarding
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
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
                  Icons.check_circle,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Pro!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your payment was successful. Your account has been upgraded and you now have access to all Pro features!',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('View Plan Details'),
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
