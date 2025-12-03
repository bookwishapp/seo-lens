import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';
import '../../data/services/billing_service.dart';

/// Upgrade screen that handles checkout from external links
class UpgradeScreen extends ConsumerStatefulWidget {
  final String? plan;

  const UpgradeScreen({super.key, this.plan});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCheckout();
  }

  Future<void> _handleCheckout() async {
    // Wait a moment for UI to render
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    try {
      final billingService = ref.read(billingServiceProvider);
      BillingPlan? billingPlan;

      // Map plan string to BillingPlan enum
      switch (widget.plan) {
        case 'pro-monthly':
          billingPlan = BillingPlan.proMonthly;
          break;
        case 'pro-yearly':
          billingPlan = BillingPlan.proYearly;
          break;
        case 'lifetime':
          billingPlan = BillingPlan.lifetime;
          break;
        default:
          setState(() {
            _error = 'Invalid plan specified';
            _isLoading = false;
          });
          return;
      }

      // Start checkout - this will redirect to Stripe
      await billingService.startCheckout(billingPlan);

      // If we get here, redirect failed - go to settings
      if (mounted) {
        context.go('/settings');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upgrade')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Checkout Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/settings'),
                  child: const Text('Go to Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Redirecting to Checkout')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Preparing your checkout session...'),
          ],
        ),
      ),
    );
  }
}
