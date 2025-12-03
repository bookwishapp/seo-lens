import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/domain.dart';
import '../../data/models/domain_status.dart';
import '../../data/models/site_page.dart';
import '../../data/providers.dart';

/// Domain detail screen
class DomainDetailScreen extends ConsumerStatefulWidget {
  final String domainId;

  const DomainDetailScreen({
    super.key,
    required this.domainId,
  });

  @override
  ConsumerState<DomainDetailScreen> createState() => _DomainDetailScreenState();
}

class _DomainDetailScreenState extends ConsumerState<DomainDetailScreen> {
  bool _isScanning = false;

  Future<void> _scanDomain({int maxPages = 50}) async {
    final domain = await ref.read(domainProvider(widget.domainId).future);
    if (domain == null) return;

    setState(() => _isScanning = true);

    final scanLabel = maxPages <= 10
        ? 'Quick scan'
        : maxPages <= 25
            ? 'Standard scan'
            : 'Deep scan';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('$scanLabel (up to $maxPages pages)...')),
            ],
          ),
          duration: Duration(seconds: maxPages * 2),
        ),
      );
    }

    try {
      // Run full scan (domain status + page crawl)
      final result = await ref.read(scanServiceProvider).fullScan(
            domainId: domain.id,
            domainName: domain.domainName,
            maxPages: maxPages,
          );

      // Invalidate all related providers to refresh data
      ref.invalidate(domainStatusProvider(widget.domainId));
      ref.invalidate(sitePagesProvider(widget.domainId));
      ref.invalidate(suggestionsProvider);
      ref.invalidate(suggestionCountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scanned ${result.pagesScanned} pages, found ${result.suggestionsCreated} issues',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Scan failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainAsync = ref.watch(domainProvider(widget.domainId));
    final statusAsync = ref.watch(domainStatusProvider(widget.domainId));
    final pagesAsync = ref.watch(sitePagesProvider(widget.domainId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Details'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<int>(
              icon: const Icon(Icons.radar),
              tooltip: 'Scan domain',
              onSelected: (maxPages) => _scanDomain(maxPages: maxPages),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 10,
                  child: ListTile(
                    leading: Icon(Icons.bolt),
                    title: Text('Quick Scan'),
                    subtitle: Text('Up to 10 pages'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 25,
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Standard Scan'),
                    subtitle: Text('Up to 25 pages'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 50,
                  child: ListTile(
                    leading: Icon(Icons.radar),
                    title: Text('Deep Scan'),
                    subtitle: Text('Up to 50 pages'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
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
                        .updateDomain(domainId: widget.domainId, notes: notes);
                    ref.invalidate(domainProvider(widget.domainId));
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
                        .updateDomain(domainId: widget.domainId, notes: notes);
                    ref.invalidate(domainProvider(widget.domainId));
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
  final Domain domain;
  final AsyncValue<DomainStatus?> statusAsync;
  final AsyncValue<List<SitePage>> pagesAsync;
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
  final Domain domain;
  final AsyncValue<DomainStatus?> statusAsync;
  final AsyncValue<List<SitePage>> pagesAsync;
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
  final Domain domain;

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
                label: Text(domain.projectTag!),
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
  final AsyncValue<DomainStatus?> statusAsync;

  const _StatusSection({required this.statusAsync});

  @override
  Widget build(BuildContext context) {
    return statusAsync.when(
      data: (status) {
        if (status == null) {
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Click the refresh button to scan this domain',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

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
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $error'),
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
  final AsyncValue<List<SitePage>> pagesAsync;

  const _PagesSection({required this.pagesAsync});

  @override
  Widget build(BuildContext context) {
    return pagesAsync.when(
      data: (pages) {
        if (pages.isEmpty) {
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No pages scanned yet. Press the refresh button to scan.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

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
                      'Pages (${pages.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...pages.map((page) {
                  final statusColor = page.httpStatus != null
                      ? (page.httpStatus! >= 200 && page.httpStatus! < 300
                          ? Colors.green
                          : page.httpStatus! >= 300 && page.httpStatus! < 400
                              ? Colors.orange
                              : Colors.red)
                      : Colors.grey;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                page.httpStatus != null && page.httpStatus! >= 200 && page.httpStatus! < 300
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: statusColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  page.title ?? 'No title',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontStyle: page.title == null ? FontStyle.italic : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (page.httpStatus != null)
                                Chip(
                                  label: Text(
                                    page.httpStatus.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: statusColor.withOpacity(0.2),
                                  side: BorderSide(color: statusColor),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            page.url,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (page.metaDescription != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              page.metaDescription!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (page.hasSeoIssues) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: page.seoIssues.map((issue) {
                                return Chip(
                                  label: Text(
                                    issue,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.orange.withOpacity(0.2),
                                  side: const BorderSide(color: Colors.orange),
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.warning, size: 14, color: Colors.orange),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Last scanned: ${_formatDate(page.lastScannedAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
