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
  bool _isNewUser = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      // Clear pending upgrade plan now that checkout succeeded
      ref.read(pendingUpgradePlanProvider.notifier).state = null;
      ref.invalidate(currentProfileProvider);
      _checkOnboardingStatus();
    });
  }

  Future<void> _checkOnboardingStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final domains = await ref.read(domainsProvider.future);

    if (mounted) {
      if (domains.isEmpty) {
        setState(() {
          _isNewUser = true;
          _isChecking = false;
        });
        // Auto-redirect new users to onboarding after showing success briefly
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/onboarding');
        }
      } else {
        setState(() {
          _isChecking = false;
        });
      }
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
                if (_isChecking)
                  const CircularProgressIndicator()
                else if (_isNewUser)
                  const Text(
                    'Redirecting to setup...',
                    style: TextStyle(color: Colors.grey),
                  )
                else ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
