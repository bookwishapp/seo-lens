import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/domain.dart';
import '../../data/plan_limits.dart';
import '../../data/providers.dart';
import '../../data/services/billing_service.dart';

/// Domains list screen
class DomainsScreen extends ConsumerStatefulWidget {
  const DomainsScreen({super.key});

  @override
  ConsumerState<DomainsScreen> createState() => _DomainsScreenState();
}

class _DomainsScreenState extends ConsumerState<DomainsScreen> {
  String _searchQuery = '';
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(domainsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search domains...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _statusFilter == null,
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Live'),
                        selected: _statusFilter == 'Live',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'Live'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Redirect'),
                        selected: _statusFilter == 'Redirect',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'Redirect'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Broken'),
                        selected: _statusFilter == 'Broken',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'Broken'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Domains list
          Expanded(
            child: domainsAsync.when(
              data: (domains) {
                var filteredDomains = domains;

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  filteredDomains = filteredDomains
                      .where((d) => d.domainName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                // TODO: Apply status filter (requires joining with domain_status)

                if (filteredDomains.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.language, size: 64),
                        const SizedBox(height: 16),
                        const Text('No domains found'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.go('/onboarding'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Domains'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;

                    if (isDesktop) {
                      return _DesktopDomainsList(domains: filteredDomains);
                    } else {
                      return _MobileDomainsList(domains: filteredDomains);
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDomainDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Domain'),
      ),
    );
  }

  void _showAddDomainDialog(BuildContext context) async {
    // Check plan limits first
    final profile = await ref.read(currentProfileProvider.future);
    final domains = await ref.read(domainsProvider.future);
    final planTier = profile?.planTier ?? 'free';
    final currentCount = domains.length;
    final maxDomains = maxDomainsForPlan(planTier);

    if (!canAddDomain(planTier, currentCount)) {
      // Show upgrade dialog instead
      if (context.mounted) {
        _showUpgradeDialog(context, maxDomains);
      }
      return;
    }

    final controller = TextEditingController();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Domain'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'example.com',
            labelText: 'Domain name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              try {
                await ref.read(domainServiceProvider).addDomain(
                      userId: user.id,
                      domainName: controller.text.trim(),
                    );
                ref.invalidate(domainsProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, int maxDomains) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Upgrade Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached the free plan limit of $maxDomains domain.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Pro or Lifetime to track up to 10 domains, plus get WHOIS lookups, weekly scans, and more!',
            ),
            const SizedBox(height: 24),
            // Plan options
            _UpgradeOption(
              title: 'Pro Monthly',
              price: '\$2.99/month',
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(billingServiceProvider).startCheckout(BillingPlan.proMonthly);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            _UpgradeOption(
              title: 'Pro Yearly',
              price: '\$19.99/year',
              badge: 'Save 44%',
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(billingServiceProvider).startCheckout(BillingPlan.proYearly);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            _UpgradeOption(
              title: 'Lifetime',
              price: '\$49.99 one-time',
              badge: 'Best Value',
              highlighted: true,
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(billingServiceProvider).startCheckout(BillingPlan.lifetime);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }
}

class _UpgradeOption extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool highlighted;
  final VoidCallback onTap;

  const _UpgradeOption({
    required this.title,
    required this.price,
    this.badge,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileDomainsList extends StatelessWidget {
  final List<Domain> domains;

  const _MobileDomainsList({required this.domains});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: domains.length,
      itemBuilder: (context, index) {
        final domain = domains[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(domain.displayName),
            subtitle: Text(domain.domainName),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/domains/${domain.id}'),
          ),
        );
      },
    );
  }
}

class _DesktopDomainsList extends StatelessWidget {
  final List<Domain> domains;

  const _DesktopDomainsList({required this.domains});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Domain')),
            DataColumn(label: Text('Label')),
            DataColumn(label: Text('Project')),
            DataColumn(label: Text('Created')),
          ],
          rows: domains.map((domain) {
            return DataRow(
              cells: [
                DataCell(
                  Text(domain.domainName),
                  onTap: () => context.go('/domains/${domain.id}'),
                ),
                DataCell(Text(domain.label ?? '-')),
                DataCell(Text(domain.projectTag ?? '-')),
                DataCell(Text(
                  '${domain.createdAt.year}-${domain.createdAt.month}-${domain.createdAt.day}',
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
