import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

              // Shared callbacks for both layouts
              Future<void> onNotesUpdated(String notes) async {
                await ref
                    .read(domainServiceProvider)
                    .updateDomain(domainId: widget.domainId, notes: notes);
                ref.invalidate(domainProvider(widget.domainId));
              }

              Future<void> onWhoisFetch() async {
                final result = await ref
                    .read(domainServiceProvider)
                    .fetchWhoisData(widget.domainId);
                if (mounted) {
                  // Determine color based on status
                  Color backgroundColor;
                  if (!result.success) {
                    backgroundColor = Colors.red;
                  } else if (result.status == 'ok') {
                    backgroundColor = Colors.green;
                  } else if (result.status == 'partial' || result.status == 'not_found') {
                    backgroundColor = Colors.blue;
                  } else {
                    backgroundColor = Colors.grey;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message ?? 'WHOIS lookup complete'),
                      backgroundColor: backgroundColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                ref.invalidate(domainProvider(widget.domainId));
              }

              Future<void> onDomainInfoUpdate(String? registrar, DateTime? expiry) async {
                await ref.read(domainServiceProvider).updateDomainInfo(
                      domainId: widget.domainId,
                      registrarName: registrar,
                      expiryDate: expiry,
                    );
                ref.invalidate(domainProvider(widget.domainId));
              }

              Future<void> onRedirectPlanUpdate(String? url, String? provider) async {
                await ref.read(domainServiceProvider).updateRedirectPreferences(
                      domainId: widget.domainId,
                      preferredUrl: url,
                      preferredRedirectProvider: provider,
                    );
                ref.invalidate(domainProvider(widget.domainId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Redirect plan saved'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }

              void onRescan() {
                _scanDomain(maxPages: 10);
              }

              if (isDesktop) {
                return _DesktopLayout(
                  domain: domain,
                  statusAsync: statusAsync,
                  pagesAsync: pagesAsync,
                  onNotesUpdated: onNotesUpdated,
                  onWhoisFetch: onWhoisFetch,
                  onDomainInfoUpdate: onDomainInfoUpdate,
                  onRedirectPlanUpdate: onRedirectPlanUpdate,
                  onRescan: onRescan,
                );
              } else {
                return _MobileLayout(
                  domain: domain,
                  statusAsync: statusAsync,
                  pagesAsync: pagesAsync,
                  onNotesUpdated: onNotesUpdated,
                  onWhoisFetch: onWhoisFetch,
                  onDomainInfoUpdate: onDomainInfoUpdate,
                  onRedirectPlanUpdate: onRedirectPlanUpdate,
                  onRescan: onRescan,
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
  final Future<void> Function() onWhoisFetch;
  final Future<void> Function(String?, DateTime?) onDomainInfoUpdate;
  final Future<void> Function(String?, String?) onRedirectPlanUpdate;
  final VoidCallback onRescan;

  const _MobileLayout({
    required this.domain,
    required this.statusAsync,
    required this.pagesAsync,
    required this.onNotesUpdated,
    required this.onWhoisFetch,
    required this.onDomainInfoUpdate,
    required this.onRedirectPlanUpdate,
    required this.onRescan,
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
          _DomainInfoSection(
            domain: domain,
            onWhoisFetch: onWhoisFetch,
            onManualUpdate: onDomainInfoUpdate,
          ),
          const SizedBox(height: 24),
          _StatusSection(statusAsync: statusAsync),
          const SizedBox(height: 24),
          _RedirectPlanSection(
            domain: domain,
            statusAsync: statusAsync,
            onSave: onRedirectPlanUpdate,
            onRescan: onRescan,
          ),
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
  final Future<void> Function() onWhoisFetch;
  final Future<void> Function(String?, DateTime?) onDomainInfoUpdate;
  final Future<void> Function(String?, String?) onRedirectPlanUpdate;
  final VoidCallback onRescan;

  const _DesktopLayout({
    required this.domain,
    required this.statusAsync,
    required this.pagesAsync,
    required this.onNotesUpdated,
    required this.onWhoisFetch,
    required this.onDomainInfoUpdate,
    required this.onRedirectPlanUpdate,
    required this.onRescan,
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
                _DomainInfoSection(
                  domain: domain,
                  onWhoisFetch: onWhoisFetch,
                  onManualUpdate: onDomainInfoUpdate,
                ),
                const SizedBox(height: 24),
                _StatusSection(statusAsync: statusAsync),
                const SizedBox(height: 24),
                _RedirectPlanSection(
                  domain: domain,
                  statusAsync: statusAsync,
                  onSave: onRedirectPlanUpdate,
                  onRescan: onRescan,
                ),
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

// ============================================================================
// Domain Info Section - WHOIS/Registrar/Expiry
// ============================================================================

class _DomainInfoSection extends StatefulWidget {
  final Domain domain;
  final Future<void> Function() onWhoisFetch;
  final Future<void> Function(String?, DateTime?) onManualUpdate;

  const _DomainInfoSection({
    required this.domain,
    required this.onWhoisFetch,
    required this.onManualUpdate,
  });

  @override
  State<_DomainInfoSection> createState() => _DomainInfoSectionState();
}

class _DomainInfoSectionState extends State<_DomainInfoSection> {
  bool _isLoading = false;
  bool _isEditing = false;
  late TextEditingController _registrarController;
  DateTime? _selectedExpiry;

  @override
  void initState() {
    super.initState();
    _registrarController = TextEditingController(text: widget.domain.registrarName ?? '');
    _selectedExpiry = widget.domain.expiryDate;
  }

  @override
  void didUpdateWidget(_DomainInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain.registrarName != widget.domain.registrarName) {
      _registrarController.text = widget.domain.registrarName ?? '';
    }
    if (oldWidget.domain.expiryDate != widget.domain.expiryDate) {
      _selectedExpiry = widget.domain.expiryDate;
    }
  }

  @override
  void dispose() {
    _registrarController.dispose();
    super.dispose();
  }

  Future<void> _fetchWhois() async {
    setState(() => _isLoading = true);
    try {
      await widget.onWhoisFetch();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveManual() async {
    await widget.onManualUpdate(
      _registrarController.text.isEmpty ? null : _registrarController.text,
      _selectedExpiry,
    );
    setState(() => _isEditing = false);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) {
      setState(() => _selectedExpiry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiryWarning = widget.domain.expiresWithinDays(30);
    final isExpired = widget.domain.isExpired;

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
                  'Domain Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!_isEditing)
                  TextButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              // Manual edit form
              TextField(
                controller: _registrarController,
                decoration: const InputDecoration(
                  labelText: 'Registrar',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Namecheap, GoDaddy',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedExpiry != null
                          ? DateFormat.yMMMd().format(_selectedExpiry!)
                          : 'Select date'),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _registrarController.text = widget.domain.registrarName ?? '';
                      _selectedExpiry = widget.domain.expiryDate;
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveManual,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              // Display mode
              _InfoRow(
                icon: Icons.business,
                label: 'Registrar',
                value: widget.domain.registrarName ?? 'Unknown',
                isUnknown: widget.domain.registrarName == null,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.event,
                label: 'Expires',
                value: widget.domain.expiryDate != null
                    ? DateFormat.yMMMd().format(widget.domain.expiryDate!)
                    : 'Unknown',
                isUnknown: widget.domain.expiryDate == null,
                warning: expiryWarning,
                error: isExpired,
                warningText: isExpired ? 'Expired!' : 'Expires soon',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fetchWhois,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Fetching...' : 'Fetch from WHOIS'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isUnknown;
  final bool warning;
  final bool error;
  final String? warningText;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isUnknown = false,
    this.warning = false,
    this.error = false,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: isUnknown ? FontStyle.italic : null,
                        color: isUnknown ? Colors.grey : null,
                      ),
                ),
                if (warning || error) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: error ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: error ? Colors.red : Colors.orange,
                      ),
                    ),
                    child: Text(
                      warningText ?? 'Warning',
                      style: TextStyle(
                        fontSize: 11,
                        color: error ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Redirect Plan Section
// ============================================================================

class _RedirectPlanSection extends StatefulWidget {
  final Domain domain;
  final AsyncValue<DomainStatus?> statusAsync;
  final Future<void> Function(String?, String?) onSave;
  final VoidCallback onRescan;

  const _RedirectPlanSection({
    required this.domain,
    required this.statusAsync,
    required this.onSave,
    required this.onRescan,
  });

  @override
  State<_RedirectPlanSection> createState() => _RedirectPlanSectionState();
}

class _RedirectPlanSectionState extends State<_RedirectPlanSection> {
  late TextEditingController _urlController;
  String? _selectedProvider;
  bool _isSaving = false;

  static const List<String> _providers = [
    'Cloudflare',
    'Netlify',
    'Vercel',
    'Namecheap',
    'GoDaddy',
    'AWS Route53',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.domain.preferredUrl ?? '');
    _selectedProvider = widget.domain.preferredRedirectProvider;
  }

  @override
  void didUpdateWidget(_RedirectPlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain.preferredUrl != widget.domain.preferredUrl) {
      _urlController.text = widget.domain.preferredUrl ?? '';
    }
    if (oldWidget.domain.preferredRedirectProvider != widget.domain.preferredRedirectProvider) {
      _selectedProvider = widget.domain.preferredRedirectProvider;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        _urlController.text.isEmpty ? null : _urlController.text,
        _selectedProvider,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _hasMismatch(DomainStatus? status) {
    if (status?.finalUrl == null || widget.domain.preferredUrl == null) {
      return false;
    }
    // Normalize URLs for comparison
    final currentUrl = status!.finalUrl!.toLowerCase().replaceAll(RegExp(r'/$'), '');
    final preferredUrl = widget.domain.preferredUrl!.toLowerCase().replaceAll(RegExp(r'/$'), '');
    return currentUrl != preferredUrl;
  }

  String _getProviderInstructions(String? provider) {
    final domainName = widget.domain.domainName;
    final preferredUrl = _urlController.text.isNotEmpty
        ? _urlController.text
        : 'https://www.your-site.com/';

    switch (provider) {
      case 'Cloudflare':
        return '''Cloudflare setup:
1. Go to your Cloudflare dashboard
2. Select your domain ($domainName)
3. Navigate to Rules → Page Rules (or Redirect Rules)
4. Create a new rule matching $domainName/*
5. Set "Forwarding URL (301)" to $preferredUrl\$1
6. Save and deploy
7. Click "Rescan" in SEO Lens to verify''';

      case 'Netlify':
        return '''Netlify setup:
1. In your site's root, create/edit _redirects file
2. Add this line:
   /*  $preferredUrl:splat  301!
3. Deploy your changes
4. Click "Rescan" in SEO Lens to verify''';

      case 'Vercel':
        return '''Vercel setup:
1. In your project root, edit vercel.json
2. Add a redirect rule:
   {
     "redirects": [
       { "source": "/:path*", "destination": "$preferredUrl:path*", "permanent": true }
     ]
   }
3. Deploy your changes
4. Click "Rescan" in SEO Lens to verify''';

      case 'Namecheap':
        return '''Namecheap setup:
1. Log in to your Namecheap account
2. Go to Domain List → Manage for $domainName
3. Navigate to Advanced DNS
4. Add a URL Redirect Record:
   - Host: @
   - Value: $preferredUrl
   - Type: Permanent (301)
5. Save changes (may take up to 48 hours)
6. Click "Rescan" in SEO Lens to verify''';

      case 'GoDaddy':
        return '''GoDaddy setup:
1. Log in to your GoDaddy account
2. Go to My Products → DNS
3. Select $domainName
4. Add a Forwarding record:
   - Forward to: $preferredUrl
   - Forward Type: Permanent (301)
5. Save changes
6. Click "Rescan" in SEO Lens to verify''';

      case 'AWS Route53':
        return '''AWS Route53 setup:
1. Go to Route 53 in the AWS Console
2. Navigate to Hosted zones → $domainName
3. Create an A record pointing to your target
4. Or use CloudFront for HTTPS redirects
5. Click "Rescan" in SEO Lens to verify''';

      case 'Other':
      default:
        return '''General redirect setup:
1. Access your DNS or hosting provider's dashboard
2. Look for "Redirects", "Forwarding", or "Page Rules"
3. Create a 301 (permanent) redirect from $domainName to $preferredUrl
4. Save changes and wait for propagation
5. Click "Rescan" in SEO Lens to verify''';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Redirect Plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Mismatch warning
            widget.statusAsync.when(
              data: (status) {
                if (_hasMismatch(status)) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current destination does not match your preferred URL',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Current: ${status?.finalUrl ?? "Unknown"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onRescan,
                          child: const Text('Rescan'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Preferred URL input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Preferred URL',
                border: OutlineInputBorder(),
                hintText: 'https://www.your-primary-site.com/',
                helperText: 'Where should this domain ultimately redirect or resolve?',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Provider dropdown
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Redirect Provider',
                border: OutlineInputBorder(),
              ),
              items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => _selectedProvider = value),
              hint: const Text('Select your provider'),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Redirect Plan'),
              ),
            ),

            // Instructions (shown when provider is selected)
            if (_selectedProvider != null && _urlController.text.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Setup Instructions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _getProviderInstructions(_selectedProvider),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
