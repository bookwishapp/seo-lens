import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/domain.dart';
import '../../data/providers.dart';

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

  void _showAddDomainDialog(BuildContext context) {
    final controller = TextEditingController();

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
