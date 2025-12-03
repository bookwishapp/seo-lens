import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';

/// Home dashboard screen
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedDomains = false;

  @override
  void initState() {
    super.initState();
    _checkDomains();
  }

  Future<void> _checkDomains() async {
    if (_hasCheckedDomains) return;
    _hasCheckedDomains = true;

    try {
      final domains = await ref.read(domainsProvider.future);
      if (mounted && domains.isEmpty) {
        context.go('/onboarding');
      }
    } catch (e) {
      // Ignore errors, let user stay on home
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(domainStatsProvider);
    final suggestionCountsAsync = ref.watch(suggestionCountsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(domainStatsProvider);
          ref.invalidate(suggestionCountsProvider);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),

                  // Stats cards
                  statsAsync.when(
                    data: (stats) {
                      if (isDesktop) {
                        return Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Domains',
                                value: stats['total']?.toString() ?? '0',
                                icon: Icons.language,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Live',
                                value: stats['live']?.toString() ?? '0',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Redirects',
                                value: stats['redirect']?.toString() ?? '0',
                                icon: Icons.arrow_forward,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Broken',
                                value: stats['broken']?.toString() ?? '0',
                                icon: Icons.error,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _StatCard(
                              title: 'Total Domains',
                              value: stats['total']?.toString() ?? '0',
                              icon: Icons.language,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: 'Live',
                                    value: stats['live']?.toString() ?? '0',
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title: 'Redirects',
                                    value: stats['redirect']?.toString() ?? '0',
                                    icon: Icons.arrow_forward,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _StatCard(
                              title: 'Broken',
                              value: stats['broken']?.toString() ?? '0',
                              icon: Icons.error,
                              color: Colors.red,
                            ),
                          ],
                        );
                      }
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Error: $error')),
                  ),

                  const SizedBox(height: 32),

                  // Suggestions section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Suggestions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () => context.go('/suggestions'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  suggestionCountsAsync.when(
                    data: (counts) {
                      final openCount = counts['open'] ?? 0;
                      if (openCount == 0) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('No open suggestions'),
                            ),
                          ),
                        );
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.lightbulb, color: Colors.amber),
                                title: Text('$openCount open suggestion${openCount == 1 ? '' : 's'}'),
                                subtitle: const Text('Review suggestions to improve your domains'),
                                trailing: const Icon(Icons.arrow_forward),
                                onTap: () => context.go('/suggestions'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (error, stack) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(child: Text('Error: $error')),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Quick actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/domains'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Domains'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/suggestions'),
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Review Suggestions'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
