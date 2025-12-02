import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';

/// Domain detail screen
class DomainDetailScreen extends ConsumerWidget {
  final String domainId;

  const DomainDetailScreen({
    super.key,
    required this.domainId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domainAsync = ref.watch(domainProvider(domainId));
    final statusAsync = ref.watch(domainStatusProvider(domainId));
    final pagesAsync = ref.watch(sitePagesProvider(domainId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final domain = await ref.read(domainProvider(domainId).future);
              if (domain == null) return;

              try {
                await ref.read(scanServiceProvider).scanDomain(
                      domainId: domain.id,
                      domainName: domain.domainName,
                    );
                ref.invalidate(domainStatusProvider(domainId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan started')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Scan failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: domainAsync.when(
        data: (domain) {
          if (domain == null) {
            return const Center(child: Text('Domain not found'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                return _DesktopLayout(
                  domain: domain,
                  statusAsync: statusAsync,
                  pagesAsync: pagesAsync,
                  onNotesUpdated: (notes) async {
                    await ref
                        .read(domainServiceProvider)
                        .updateDomain(domainId: domainId, notes: notes);
                    ref.invalidate(domainProvider(domainId));
                  },
                );
              } else {
                return _MobileLayout(
                  domain: domain,
                  statusAsync: statusAsync,
                  pagesAsync: pagesAsync,
                  onNotesUpdated: (notes) async {
                    await ref
                        .read(domainServiceProvider)
                        .updateDomain(domainId: domainId, notes: notes);
                    ref.invalidate(domainProvider(domainId));
                  },
                );
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final domain;
  final statusAsync;
  final pagesAsync;
  final Function(String) onNotesUpdated;

  const _MobileLayout({
    required this.domain,
    required this.statusAsync,
    required this.pagesAsync,
    required this.onNotesUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderSection(domain: domain),
          const SizedBox(height: 24),
          _StatusSection(statusAsync: statusAsync),
          const SizedBox(height: 24),
          _PagesSection(pagesAsync: pagesAsync),
          const SizedBox(height: 24),
          _NotesSection(domain: domain, onSave: onNotesUpdated),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final domain;
  final statusAsync;
  final pagesAsync;
  final Function(String) onNotesUpdated;

  const _DesktopLayout({
    required this.domain,
    required this.statusAsync,
    required this.pagesAsync,
    required this.onNotesUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(domain: domain),
                const SizedBox(height: 24),
                _StatusSection(statusAsync: statusAsync),
                const SizedBox(height: 24),
                _NotesSection(domain: domain, onSave: onNotesUpdated),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: _PagesSection(pagesAsync: pagesAsync),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final domain;

  const _HeaderSection({required this.domain});

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
                const Icon(Icons.language, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (domain.label != null)
                        Text(
                          domain.domainName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (domain.projectTag != null) ...[
              const SizedBox(height: 12),
              Chip(
                label: Text(domain.projectTag),
                avatar: const Icon(Icons.folder, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  final statusAsync;

  const _StatusSection({required this.statusAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status & Redirects',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            statusAsync.when(
              data: (status) {
                if (status == null) {
                  return const Text('Not yet scanned');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(status: status.statusLabel),
                    const SizedBox(height: 12),
                    if (status.finalUrl != null) ...[
                      const Text('Final URL:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(status.finalUrl!),
                      const SizedBox(height: 8),
                    ],
                    if (status.finalStatusCode != null) ...[
                      const Text('Status Code:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(status.finalStatusCode.toString()),
                      const SizedBox(height: 8),
                    ],
                    if (status.hasRedirects) ...[
                      const Text('Redirect Chain:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ...status.redirectChain!.map((hop) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_forward, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${hop.url} (${hop.statusCode})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Last checked: ${_formatDate(status.lastCheckedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Live':
        color = Colors.green;
        break;
      case 'Redirect':
        color = Colors.orange;
        break;
      case 'Broken':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
    );
  }
}

class _PagesSection extends StatelessWidget {
  final pagesAsync;

  const _PagesSection({required this.pagesAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            pagesAsync.when(
              data: (pages) {
                if (pages.isEmpty) {
                  return const Text('No pages scanned yet');
                }

                return Column(
                  children: pages.map((page) {
                    return ListTile(
                      leading: Icon(
                        page.httpStatus == 200
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                            page.httpStatus == 200 ? Colors.green : Colors.red,
                      ),
                      title: Text(page.title ?? page.url),
                      subtitle: Text(page.url),
                      trailing: page.hasSeoIssues
                          ? const Icon(Icons.warning, color: Colors.orange)
                          : null,
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesSection extends StatefulWidget {
  final domain;
  final Function(String) onSave;

  const _NotesSection({
    required this.domain,
    required this.onSave,
  });

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.domain.notes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!_isEditing)
                  TextButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditing) ...[
              TextField(
                controller: _controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add notes about this domain...',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _controller.text = widget.domain.notes ?? '';
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await widget.onSave(_controller.text);
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                _controller.text.isEmpty
                    ? 'No notes yet'
                    : _controller.text,
                style: _controller.text.isEmpty
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
