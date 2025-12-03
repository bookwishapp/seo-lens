// lib/ui/screens/referral_screen.dart
// Referral program screen with link sharing and stats

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/providers.dart';

/// Referral program screen
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final referralCountAsync = ref.watch(referralCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Program'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero section
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              size: 40,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite friends, earn free months',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Get 1 free month of Pro for each friend who subscribes',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // How it works
                Text(
                  'How it works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _HowItWorksStep(
                  number: '1',
                  title: 'Share your link',
                  description: 'Send your unique referral link to friends who manage domains.',
                ),
                _HowItWorksStep(
                  number: '2',
                  title: 'They sign up',
                  description: 'Your friend creates a free account using your link.',
                ),
                _HowItWorksStep(
                  number: '3',
                  title: 'They upgrade to Pro',
                  description: 'When they subscribe to Pro within 90 days, you both win!',
                ),
                _HowItWorksStep(
                  number: '4',
                  title: 'You get 1 free month',
                  description: 'We\'ll add a free month of Pro to your account.',
                  isLast: true,
                ),

                const SizedBox(height: 32),

                // Your referral link
                Text(
                  'Your referral link',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Loading...'),
                        ),
                      );
                    }

                    final referralLink = profile.referralLink;
                    if (referralLink.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Referral code not available yet. Please try again later.'),
                        ),
                      );
                    }

                    return _ReferralLinkCard(
                      referralLink: referralLink,
                      referralCode: profile.referralCode!,
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: $error'),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Your stats
                Text(
                  'Your referral stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Loading...'),
                        ),
                      );
                    }

                    return _StatsCard(
                      freeMonthsEarned: profile.referralFreeMonthsEarned,
                      freeMonthsThisYear: profile.referralFreeMonthsThisYear,
                      freeUntil: profile.referralFreeUntil,
                      successfulReferrals: referralCountAsync.maybeWhen(
                        data: (count) => count,
                        orElse: () => 0,
                      ),
                    );
                  },
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: $error'),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Terms
                Card(
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Program terms',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• You earn 1 free month of Pro for each friend who subscribes to Pro within 90 days of signing up.\n'
                          '• Maximum 6 free months per calendar year.\n'
                          '• Rewards apply to Pro subscriptions only (not Lifetime).\n'
                          '• Your friend doesn\'t get a discount, but they can try the free plan first.\n'
                          '• We reserve the right to modify or end this program at any time.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final bool isLast;

  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralLinkCard extends ConsumerStatefulWidget {
  final String referralLink;
  final String referralCode;

  const _ReferralLinkCard({
    required this.referralLink,
    required this.referralCode,
  });

  @override
  ConsumerState<_ReferralLinkCard> createState() => _ReferralLinkCardState();
}

class _ReferralLinkCardState extends ConsumerState<_ReferralLinkCard> {
  bool _copied = false;

  Future<void> _copyLink() async {
    final referralService = ref.read(referralServiceProvider);
    final success = await referralService.copyReferralLink(widget.referralCode);

    if (success && mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral link copied!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Reset copied state after a moment
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _copied = false);
        }
      });
    }
  }

  Future<void> _shareLink() async {
    final referralService = ref.read(referralServiceProvider);
    await referralService.shareReferralLink(widget.referralCode);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                widget.referralLink,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _copyLink,
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(_copied ? 'Copied!' : 'Copy link'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int freeMonthsEarned;
  final int freeMonthsThisYear;
  final DateTime? freeUntil;
  final int successfulReferrals;

  const _StatsCard({
    required this.freeMonthsEarned,
    required this.freeMonthsThisYear,
    this.freeUntil,
    required this.successfulReferrals,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFreeTime = freeUntil != null && freeUntil!.isAfter(DateTime.now());
    final remainingSlots = 6 - freeMonthsThisYear;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.people,
                    value: successfulReferrals.toString(),
                    label: 'Successful referrals',
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.calendar_month,
                    value: freeMonthsEarned.toString(),
                    label: 'Free months earned',
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.stars,
                    value: remainingSlots.toString(),
                    label: 'Slots left this year',
                  ),
                ),
              ],
            ),
            if (hasActiveFreeTime) ...[
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have free Pro until ${DateFormat.yMMMd().format(freeUntil!)}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!hasActiveFreeTime && freeMonthsEarned == 0) ...[
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Share your link to start earning free months!',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
