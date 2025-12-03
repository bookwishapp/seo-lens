// lib/ui/screens/settings_screen.dart
// Settings screen with account, plan info, billing, and preferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/plan_limits.dart';
import '../../data/providers.dart';
import '../../data/services/billing_service.dart';
import '../../data/models/profile.dart';

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayNameController = TextEditingController();
  String _scanFrequency = 'manual';
  bool _isCheckingOut = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout(BillingPlan plan) async {
    setState(() => _isCheckingOut = true);

    try {
      await ref.read(billingServiceProvider).startCheckout(plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),

              // Plan section (at the top)
              Text(
                'Your Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Loading plan info...'),
                      ),
                    );
                  }
                  return _PlanCard(
                    profile: profile,
                    isCheckingOut: _isCheckingOut,
                    onUpgrade: _startCheckout,
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
                    child: Text('Error loading plan: $error'),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Referral section
              Text(
                'Referral Program',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              profileAsync.when(
                data: (profile) => _ReferralCard(profile: profile),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Error loading referral info'),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Account section
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: userAsync != null
                            ? Text(userAsync.email ?? 'Not available')
                            : const Text('Loading...'),
                      ),
                      const Divider(),
                      profileAsync.when(
                        data: (profile) {
                          if (profile != null &&
                              _displayNameController.text.isEmpty) {
                            _displayNameController.text =
                                profile.displayName ?? '';
                          }
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: TextField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            trailing: FilledButton(
                              onPressed: () async {
                                final user = ref.read(currentUserProvider);
                                if (user == null) return;

                                await ref
                                    .read(authServiceProvider)
                                    .updateProfile(
                                      userId: user.id,
                                      displayName: _displayNameController.text,
                                    );
                                ref.invalidate(currentProfileProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Profile updated')),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          );
                        },
                        loading: () => const ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Loading...'),
                        ),
                        error: (error, stack) => ListTile(
                          leading: const Icon(Icons.error),
                          title: Text('Error: $error'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Scan preferences
              Text(
                'Scan Preferences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              profileAsync.when(
                data: (profile) {
                  final planTier = profile?.planTier ?? 'free';
                  final canUseWeekly = canUseWeeklyScan(planTier);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Frequency',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'How often should we automatically scan your domains?',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          RadioListTile<String>(
                            title: const Text('Manual only'),
                            subtitle:
                                const Text('Scan only when you trigger it'),
                            value: 'manual',
                            groupValue: _scanFrequency,
                            onChanged: (value) =>
                                setState(() => _scanFrequency = value!),
                          ),
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                const Text('Weekly'),
                                if (!canUseWeekly) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Pro',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              canUseWeekly
                                  ? 'Scan all domains once per week'
                                  : 'Upgrade to Pro to enable automatic weekly scans',
                            ),
                            value: 'weekly',
                            groupValue: _scanFrequency,
                            onChanged: canUseWeekly
                                ? (value) =>
                                    setState(() => _scanFrequency = value!)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Error loading preferences'),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Danger zone
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Sign Out'),
                        subtitle: const Text(
                            'Sign out of your account on this device'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await ref.read(authServiceProvider).signOut();
                            if (context.mounted) {
                              context.go('/auth');
                            }
                          },
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plan info card with upgrade buttons
class _PlanCard extends StatelessWidget {
  final dynamic profile; // Profile type
  final bool isCheckingOut;
  final Function(BillingPlan) onUpgrade;

  const _PlanCard({
    required this.profile,
    required this.isCheckingOut,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final planTier = profile.planTier as String;
    final planFeatures = PlanFeatures.forTier(planTier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current plan info
            Row(
              children: [
                Icon(
                  planTier == 'free'
                      ? Icons.person
                      : planTier == 'lifetime'
                          ? Icons.star
                          : Icons.workspace_premium,
                  size: 32,
                  color: planTier == 'free'
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.planDisplayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (planTier == 'lifetime') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber),
                              ),
                              child: const Text(
                                'Founding Member',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (planTier == 'pro' &&
                          profile.planRenewsInterval != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Billed ${profile.billingIntervalDisplayName?.toLowerCase() ?? 'monthly'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (planTier == 'pro' &&
                          profile.planCurrentPeriodEnd != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Renews ${DateFormat.yMMMd().format(profile.planCurrentPeriodEnd!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Plan limits summary
            Text(
              'Your limits:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LimitChip(
                  icon: Icons.language,
                  label: '${planFeatures.maxDomains} domain${planFeatures.maxDomains > 1 ? 's' : ''}',
                ),
                _LimitChip(
                  icon: Icons.article,
                  label: '${planFeatures.maxPagesPerScan} pages/scan',
                ),
                _LimitChip(
                  icon: planFeatures.weeklyScan
                      ? Icons.schedule
                      : Icons.touch_app,
                  label: planFeatures.weeklyScan ? 'Auto weekly scans' : 'Manual scans',
                ),
                _LimitChip(
                  icon: planFeatures.whoisEnabled
                      ? Icons.check_circle
                      : Icons.cancel,
                  label: planFeatures.whoisEnabled ? 'WHOIS lookup' : 'No WHOIS',
                  enabled: planFeatures.whoisEnabled,
                ),
              ],
            ),

            // Upgrade buttons (only show for free users)
            if (planTier == 'free') ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Upgrade your plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Get more domains, automatic scans, and WHOIS lookups.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _UpgradeButton(
                    label: 'Pro Monthly',
                    price: '\$2.99/mo',
                    onPressed: isCheckingOut
                        ? null
                        : () => onUpgrade(BillingPlan.proMonthly),
                    isLoading: isCheckingOut,
                  ),
                  _UpgradeButton(
                    label: 'Pro Yearly',
                    price: '\$19.99/yr',
                    badge: 'Save 44%',
                    onPressed: isCheckingOut
                        ? null
                        : () => onUpgrade(BillingPlan.proYearly),
                    isLoading: isCheckingOut,
                  ),
                  _UpgradeButton(
                    label: 'Lifetime',
                    price: '\$49.99',
                    badge: 'Best Value',
                    isPrimary: true,
                    onPressed: isCheckingOut
                        ? null
                        : () => onUpgrade(BillingPlan.lifetime),
                    isLoading: isCheckingOut,
                  ),
                ],
              ),
            ],

            // Thank you message for lifetime users
            if (planTier == 'lifetime') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thank you for being a founding lifetime member! You have permanent access to all Pro features.',
                        style: TextStyle(color: Colors.green.shade800),
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

class _LimitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;

  const _LimitChip({
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? Colors.grey.shade100 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? Colors.grey.shade300 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: enabled ? Colors.grey.shade700 : Colors.red.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? Colors.grey.shade700 : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isPrimary;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _UpgradeButton({
    required this.label,
    required this.price,
    this.badge,
    this.isPrimary = false,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isPrimary)
          FilledButton(
            onPressed: onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      Text(
                        price,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
          )
        else
          OutlinedButton(
            onPressed: onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
          ),
        if (badge != null)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.amber : Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Referral program card for settings
class _ReferralCard extends ConsumerStatefulWidget {
  final Profile? profile;

  const _ReferralCard({required this.profile});

  @override
  ConsumerState<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends ConsumerState<_ReferralCard> {
  bool _copied = false;

  Future<void> _copyLink() async {
    if (widget.profile?.referralCode == null) return;

    final referralService = ref.read(referralServiceProvider);
    final success = await referralService.copyReferralLink(widget.profile!.referralCode!);

    if (success && mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral link copied!'),
          duration: Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _copied = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    if (profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Loading...'),
        ),
      );
    }

    final hasReferralCode = profile.referralCode != null;
    final hasActiveFreeTime = profile.hasReferralFreeTime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share SEO Lens, earn free months',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get 1 free month of Pro when someone signs up with your link and upgrades to Pro within 90 days.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (hasReferralCode) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _MiniStat(
                    label: 'Earned',
                    value: '${profile.referralFreeMonthsEarned} mo',
                  ),
                  const SizedBox(width: 24),
                  _MiniStat(
                    label: 'This year',
                    value: '${profile.referralFreeMonthsThisYear}/6',
                  ),
                  if (hasActiveFreeTime) ...[
                    const SizedBox(width: 24),
                    _MiniStat(
                      label: 'Free until',
                      value: DateFormat.MMMd().format(profile.referralFreeUntil!),
                      highlight: true,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                      label: Text(_copied ? 'Copied!' : 'Copy link'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => context.push('/referral'),
                    child: const Text('View details'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.green : null,
          ),
        ),
      ],
    );
  }
}
