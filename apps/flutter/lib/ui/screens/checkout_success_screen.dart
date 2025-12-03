import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';
import '../../supabase_config.dart';

/// Screen shown after successful Stripe checkout
class CheckoutSuccessScreen extends ConsumerStatefulWidget {
  const CheckoutSuccessScreen({super.key});

  @override
  ConsumerState<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends ConsumerState<CheckoutSuccessScreen> {
  bool _isNewUser = false;
  bool _isChecking = true;
  bool _magicLinkSent = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(pendingUpgradePlanProvider.notifier).state = null;
      // Capture referral code from URL before any redirects
      // This ensures it's stored in localStorage for when user clicks magic link
      ref.read(referralServiceProvider).captureReferralCodeFromUrl();
      _handleCheckoutSuccess();
    });
  }

  Future<void> _handleCheckoutSuccess() async {
    final user = ref.read(currentUserProvider);

    if (user == null) {
      // Guest checkout - user not authenticated yet
      // Send magic link so they can log in
      await _sendMagicLink();
    } else {
      // Authenticated user - check if they need onboarding
      ref.invalidate(currentProfileProvider);
      await _checkOnboardingStatus();
    }
  }

  Future<void> _sendMagicLink() async {
    try {
      // Get session_id from URL
      final sessionId = Uri.base.queryParameters['session_id'];

      if (sessionId == null) {
        setState(() {
          _isChecking = false;
        });
        return;
      }

      // Call edge function to send magic link
      final response = await supabase.functions.invoke(
        'send-checkout-magic-link',
        body: {'session_id': sessionId},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _magicLinkSent = true;
          _userEmail = data['email'] as String?;
          _isChecking = false;
        });
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
    }
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
                  _magicLinkSent ? 'Check Your Email!' : 'Welcome to Pro!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _magicLinkSent
                      ? 'Your payment was successful! We\'ve sent a magic link to ${_userEmail ?? "your email"}. Click the link to log in and start using SEO Lens.'
                      : 'Your payment was successful. Your account has been upgraded and you now have access to all Pro features!',
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
