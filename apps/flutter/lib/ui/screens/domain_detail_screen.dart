import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/domain.dart';
import '../../data/models/domain_status.dart';
import '../../data/models/site_page.dart';
import '../../data/models/suggestion.dart';
import '../../data/plan_limits.dart';
import '../../data/providers.dart';
import '../../data/services/billing_service.dart';

/// Domain detail screen with lens-based tabbed layout
class DomainDetailScreen extends ConsumerStatefulWidget {
  final String domainId;

  const DomainDetailScreen({
    super.key,
    required this.domainId,
  });

  @override
  ConsumerState<DomainDetailScreen> createState() => _DomainDetailScreenState();
}

class _DomainDetailScreenState extends ConsumerState<DomainDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;
  bool _isReportLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
      final result = await ref.read(scanServiceProvider).fullScan(
            domainId: domain.id,
            domainName: domain.domainName,
            maxPages: maxPages,
          );

      // Invalidate all related providers to refresh data
      ref.invalidate(domainProvider(widget.domainId));
      ref.invalidate(domainStatusProvider(widget.domainId));
      ref.invalidate(sitePagesProvider(widget.domainId));
      ref.invalidate(suggestionsProvider);
      ref.invalidate(suggestionCountsProvider);
      ref.invalidate(domainSuggestionsProvider(widget.domainId));

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

  Future<void> _enablePublicReport(Domain domain) async {
    setState(() => _isReportLoading = true);
    try {
      final token = await ref.read(reportServiceProvider).enablePublicReport(domain.id);
      ref.invalidate(domainProvider(widget.domainId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Public report enabled! Link copied to clipboard.'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => context.go('/report/$token'),
            ),
          ),
        );
        // Copy link to clipboard
        final reportUrl = '${Uri.base.origin}/report/$token';
        await Clipboard.setData(ClipboardData(text: reportUrl));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReportLoading = false);
    }
  }

  Future<void> _disablePublicReport(Domain domain) async {
    setState(() => _isReportLoading = true);
    try {
      await ref.read(reportServiceProvider).disablePublicReport(domain.id);
      ref.invalidate(domainProvider(widget.domainId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public report disabled'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disable report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReportLoading = false);
    }
  }

  void _copyReportLink(Domain domain) {
    if (domain.publicReportToken == null) return;
    final reportUrl = '${Uri.base.origin}/report/${domain.publicReportToken}';
    Clipboard.setData(ClipboardData(text: reportUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report link copied to clipboard'), backgroundColor: Colors.green),
    );
  }

  void _viewPublicReport(Domain domain) {
    if (domain.publicReportToken == null) return;
    context.go('/report/${domain.publicReportToken}');
  }

  Future<void> _downloadPdfReport(Domain domain) async {
    setState(() => _isReportLoading = true);
    try {
      // Fetch the report data
      final reportData = await ref.read(publicReportProvider(domain.publicReportToken!).future);

      // Generate PDF
      final pdfService = ref.read(reportPdfServiceProvider);
      final bytes = await pdfService.buildReportPdf(reportData);

      // Trigger download in web
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${domain.domainName.replaceAll('.', '-')}-seo-report.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainAsync = ref.watch(domainProvider(widget.domainId));
    final statusAsync = ref.watch(domainStatusProvider(widget.domainId));
    final pagesAsync = ref.watch(sitePagesProvider(widget.domainId));
    final suggestionsAsync = ref.watch(domainSuggestionsProvider(widget.domainId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Details'),
        actions: [
          // Reports menu
          if (_isReportLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (domainAsync.valueOrNull != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.description),
              tooltip: 'Reports',
              onSelected: (action) {
                final domain = domainAsync.valueOrNull!;
                switch (action) {
                  case 'view':
                    _viewPublicReport(domain);
                    break;
                  case 'copy':
                    _copyReportLink(domain);
                    break;
                  case 'enable':
                    _enablePublicReport(domain);
                    break;
                  case 'disable':
                    _disablePublicReport(domain);
                    break;
                  case 'pdf':
                    _downloadPdfReport(domain);
                    break;
                }
              },
              itemBuilder: (context) {
                final domain = domainAsync.valueOrNull!;
                final isEnabled = domain.publicReportEnabled;
                final hasToken = domain.publicReportToken != null;

                return [
                  if (isEnabled && hasToken) ...[
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.open_in_new),
                        title: Text('View public report'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('Copy report link'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf),
                        title: Text('Download PDF'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'disable',
                      child: ListTile(
                        leading: Icon(Icons.visibility_off, color: Colors.orange),
                        title: Text('Disable public report'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ] else ...[
                    const PopupMenuItem(
                      value: 'enable',
                      child: ListTile(
                        leading: Icon(Icons.visibility, color: Colors.green),
                        title: Text('Enable public report'),
                        subtitle: Text('Generate a shareable link'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ];
              },
            ),
          // Scan menu
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Essentials', icon: Icon(Icons.checklist)),
            Tab(text: 'Redirects', icon: Icon(Icons.alt_route)),
            Tab(text: 'Uptime', icon: Icon(Icons.monitor_heart)),
            Tab(text: 'Expiry', icon: Icon(Icons.event)),
            // TODO: Future "Queries" lens for Google Search Console integration
          ],
        ),
      ),
      body: domainAsync.when(
        data: (domain) {
          if (domain == null) {
            return const Center(child: Text('Domain not found'));
          }

          // Get plan tier for WHOIS access
          final profileAsync = ref.watch(currentProfileProvider);
          final planTier = profileAsync.maybeWhen(
            data: (profile) => profile?.planTier ?? 'free',
            orElse: () => 'free',
          );
          final whoisEnabled = canUseWhois(planTier);

          return TabBarView(
            controller: _tabController,
            children: [
              // Overview Lens
              _OverviewLens(
                domain: domain,
                suggestionsAsync: suggestionsAsync,
                onRescan: () => _scanDomain(maxPages: 10),
              ),
              // Essentials Lens
              _EssentialsLens(
                domain: domain,
                pagesAsync: pagesAsync,
              ),
              // Redirects Lens
              _RedirectsLens(
                domain: domain,
                statusAsync: statusAsync,
                onRescan: () => _scanDomain(maxPages: 10),
                onRedirectPlanUpdate: (url, provider) async {
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
                },
              ),
              // Uptime Lens
              _UptimeLens(
                domain: domain,
                onUptimeSettingsUpdate: (enabled, interval) async {
                  await ref.read(domainServiceProvider).updateUptimeSettings(
                        domainId: widget.domainId,
                        uptimeEnabled: enabled,
                        uptimeCheckIntervalMinutes: interval,
                      );
                  ref.invalidate(domainProvider(widget.domainId));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(enabled
                            ? 'Uptime monitoring enabled'
                            : 'Uptime monitoring disabled'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              // Expiry Lens
              _ExpiryLens(
                domain: domain,
                whoisEnabled: whoisEnabled,
                onWhoisFetch: () async {
                  final result = await ref
                      .read(domainServiceProvider)
                      .fetchWhoisData(widget.domainId);
                  if (mounted) {
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
                },
                onWhoisUpgrade: () => _showWhoisUpgradeDialog(context),
                onDomainInfoUpdate: (registrar, expiry) async {
                  await ref.read(domainServiceProvider).updateDomainInfo(
                        domainId: widget.domainId,
                        registrarName: registrar,
                        expiryDate: expiry,
                      );
                  ref.invalidate(domainProvider(widget.domainId));
                },
                onNotesUpdated: (notes) async {
                  await ref
                      .read(domainServiceProvider)
                      .updateDomain(domainId: widget.domainId, notes: notes);
                  ref.invalidate(domainProvider(widget.domainId));
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showWhoisUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Pro Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHOIS lookups are a Pro feature.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to automatically fetch registrar and expiry date information for your domains.',
            ),
            const SizedBox(height: 24),
            _WhoisUpgradeOption(
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
            _WhoisUpgradeOption(
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
            _WhoisUpgradeOption(
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

// ============================================================================
// OVERVIEW LENS - Health score, top suggestions, quick summary
// ============================================================================

class _OverviewLens extends StatelessWidget {
  final Domain domain;
  final AsyncValue<List<Suggestion>> suggestionsAsync;
  final VoidCallback onRescan;

  const _OverviewLens({
    required this.domain,
    required this.suggestionsAsync,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(domain: domain),
          const SizedBox(height: 16),
          _HealthScoreCard(domain: domain),
          const SizedBox(height: 16),
          _TopSuggestionsCard(
            suggestionsAsync: suggestionsAsync,
            domain: domain,
          ),
          const SizedBox(height: 16),
          _QuickStatsCard(domain: domain),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Domain domain;

  const _HeaderCard({required this.domain});

  String _formatLastScan(DateTime? lastScan) {
    if (lastScan == null) return 'Never scanned';
    // Convert UTC to local time
    final localScan = lastScan.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localScan);
    if (diff.inMinutes < 1) return 'Scanned just now';
    if (diff.inMinutes < 60) return 'Scanned ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Scanned ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Scanned yesterday';
    if (diff.inDays < 7) return 'Scanned ${diff.inDays}d ago';
    return 'Scanned on ${DateFormat.MMMd().format(localScan)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.language, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (domain.label != null)
                    Text(
                      domain.domainName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.radar,
                        size: 14,
                        color: domain.lastScanAt != null ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatLastScan(domain.lastScanAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: domain.lastScanAt != null ? Colors.green[700] : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  if (domain.projectTag != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(domain.projectTag!),
                      avatar: const Icon(Icons.folder, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final Domain domain;

  const _HealthScoreCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    final hasScore = domain.healthScore != null;
    final score = domain.healthScore ?? 0;

    Color scoreColor;
    switch (domain.healthScoreLevel) {
      case HealthScoreLevel.good:
        scoreColor = Colors.green;
        break;
      case HealthScoreLevel.warning:
        scoreColor = Colors.orange;
        break;
      case HealthScoreLevel.poor:
        scoreColor = Colors.red;
        break;
      case HealthScoreLevel.unknown:
        scoreColor = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety, size: 24),
                const SizedBox(width: 8),
                Text(
                  'SEO Health',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasScore)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Scan this domain to see health score',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withOpacity(0.1),
                      border: Border.all(color: scoreColor, width: 4),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$score',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '/100',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scoreColor,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Breakdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BreakdownRow(
                          icon: Icons.title,
                          label: 'Titles',
                          percentage: domain.titlePercentage,
                        ),
                        const SizedBox(height: 8),
                        _BreakdownRow(
                          icon: Icons.description,
                          label: 'Meta descriptions',
                          percentage: domain.metaPercentage,
                        ),
                        const SizedBox(height: 8),
                        _BreakdownRow(
                          icon: Icons.looks_one,
                          label: 'H1 headings',
                          percentage: domain.h1Percentage,
                        ),
                        const SizedBox(height: 8),
                        _ErrorRow(
                          errorCount: domain.totalErrorPages,
                          totalPages: domain.totalPagesScanned ?? 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (domain.lastScanAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last scan: ${_formatDate(domain.lastScanAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Convert UTC to local time
    return DateFormat.yMMMd().add_jm().format(date.toLocal());
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double percentage;

  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percentage * 100).round();
    final isGood = pct >= 80;
    final color = isGood ? Colors.green : (pct >= 50 ? Colors.orange : Colors.red);

    return Row(
      children: [
        Icon(
          isGood ? Icons.check_circle : Icons.warning_amber,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $pct%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final int errorCount;
  final int totalPages;

  const _ErrorRow({required this.errorCount, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    final hasErrors = errorCount > 0;

    return Row(
      children: [
        Icon(
          hasErrors ? Icons.error : Icons.check_circle,
          size: 16,
          color: hasErrors ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasErrors
                ? 'Errors: $errorCount of $totalPages pages'
                : 'No error pages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _TopSuggestionsCard extends StatelessWidget {
  final AsyncValue<List<Suggestion>> suggestionsAsync;
  final Domain domain;

  const _TopSuggestionsCard({
    required this.suggestionsAsync,
    required this.domain,
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
                const Icon(Icons.lightbulb_outline, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Top Suggestions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            suggestionsAsync.when(
              data: (suggestions) {
                final openSuggestions = suggestions
                    .where((s) => s.status == SuggestionStatus.open)
                    .toList()
                  ..sort((a, b) {
                    // Sort by severity (high first)
                    final severityOrder = {'high': 0, 'medium': 1, 'low': 2};
                    return (severityOrder[a.severity.name] ?? 1)
                        .compareTo(severityOrder[b.severity.name] ?? 1);
                  });

                if (openSuggestions.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green[300]),
                        const SizedBox(height: 8),
                        Text(
                          'No open suggestions',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final topSuggestions = openSuggestions.take(3).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have ${openSuggestions.length} open suggestion${openSuggestions.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ...topSuggestions.map((s) => _SuggestionPreview(suggestion: s)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPreview extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback? onPageTap;

  const _SuggestionPreview({
    required this.suggestion,
    this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SeverityBadge(severity: suggestion.severity),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                // Show page path if available
                if (suggestion.page != null) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: onPageTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          suggestion.page!.path,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ] else if (suggestion.effectiveScope == SuggestionScope.domain) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Domain-wide',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
                if (suggestion.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final SuggestionSeverity severity;

  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (severity) {
      case SuggestionSeverity.high:
        color = Colors.red;
        break;
      case SuggestionSeverity.medium:
        color = Colors.orange;
        break;
      case SuggestionSeverity.low:
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  final Domain domain;

  const _QuickStatsCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.pages,
                  value: '${domain.totalPagesScanned ?? 0}',
                  label: 'Pages',
                ),
                _StatItem(
                  icon: Icons.check_circle,
                  value: '${domain.pages2xx ?? 0}',
                  label: 'OK',
                  color: Colors.green,
                ),
                _StatItem(
                  icon: Icons.warning,
                  value: '${domain.pages4xx ?? 0}',
                  label: '4xx',
                  color: Colors.orange,
                ),
                _StatItem(
                  icon: Icons.error,
                  value: '${domain.pages5xx ?? 0}',
                  label: '5xx',
                  color: Colors.red,
                ),
              ],
            ),
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
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}

// ============================================================================
// ESSENTIALS LENS - Pages with SEO elements and filters
// ============================================================================

class _EssentialsLens extends ConsumerStatefulWidget {
  final Domain domain;
  final AsyncValue<List<SitePage>> pagesAsync;

  const _EssentialsLens({
    required this.domain,
    required this.pagesAsync,
  });

  @override
  ConsumerState<_EssentialsLens> createState() => _EssentialsLensState();
}

class _EssentialsLensState extends ConsumerState<_EssentialsLens> {
  String _filter = 'all';

  List<SitePage> _filterPages(List<SitePage> pages, Map<String, int> suggestionCounts) {
    switch (_filter) {
      case 'missing_title':
        return pages.where((p) => p.title == null || p.title!.isEmpty).toList();
      case 'missing_meta':
        return pages.where((p) => p.metaDescription == null || p.metaDescription!.isEmpty).toList();
      case 'missing_h1':
        return pages.where((p) => p.h1 == null || p.h1!.isEmpty).toList();
      case 'errors':
        return pages.where((p) => p.httpStatus != null && p.httpStatus! >= 400).toList();
      case 'has_keyword':
        return pages.where((p) => p.hasPrimaryKeyword).toList();
      case 'no_keyword':
        return pages.where((p) => !p.hasPrimaryKeyword).toList();
      case 'has_suggestions':
        return pages.where((p) => (suggestionCounts[p.id] ?? 0) > 0).toList();
      default:
        return pages;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Info card about primary keywords
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set a primary keyword for each page to check if it appears in the title, meta description, and H1.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Missing Title'),
                selected: _filter == 'missing_title',
                onSelected: (_) => setState(() => _filter = 'missing_title'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Missing Meta'),
                selected: _filter == 'missing_meta',
                onSelected: (_) => setState(() => _filter = 'missing_meta'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Missing H1'),
                selected: _filter == 'missing_h1',
                onSelected: (_) => setState(() => _filter = 'missing_h1'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Errors'),
                selected: _filter == 'errors',
                onSelected: (_) => setState(() => _filter = 'errors'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Has Keyword'),
                selected: _filter == 'has_keyword',
                onSelected: (_) => setState(() => _filter = 'has_keyword'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('No Keyword'),
                selected: _filter == 'no_keyword',
                onSelected: (_) => setState(() => _filter = 'no_keyword'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Has Suggestions'),
                selected: _filter == 'has_suggestions',
                onSelected: (_) => setState(() => _filter = 'has_suggestions'),
              ),
            ],
          ),
        ),
        // Pages list
        Expanded(
          child: widget.pagesAsync.when(
            data: (pages) {
              // Get suggestion counts per page
              final suggestionCountsAsync = ref.watch(suggestionCountsByPageProvider(widget.domain.id));
              final suggestionCounts = suggestionCountsAsync.valueOrNull ?? {};
              final filteredPages = _filterPages(pages, suggestionCounts);

              if (pages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No pages scanned yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      const Text('Use the scan button to crawl this domain'),
                    ],
                  ),
                );
              }

              if (filteredPages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
                      const SizedBox(height: 16),
                      const Text('No pages match this filter'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredPages.length,
                itemBuilder: (context, index) {
                  final page = filteredPages[index];
                  final suggestionCount = suggestionCounts[page.id] ?? 0;
                  return _PageCard(
                    page: page,
                    suggestionCount: suggestionCount,
                    onKeywordUpdated: (keyword) async {
                      await ref.read(domainServiceProvider).updatePagePrimaryKeyword(
                            pageId: page.id,
                            primaryKeyword: keyword,
                          );
                      ref.invalidate(sitePagesProvider(widget.domain.id));
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _PageCard extends StatefulWidget {
  final SitePage page;
  final int suggestionCount;
  final Future<void> Function(String?) onKeywordUpdated;

  const _PageCard({
    required this.page,
    required this.suggestionCount,
    required this.onKeywordUpdated,
  });

  @override
  State<_PageCard> createState() => _PageCardState();
}

class _PageCardState extends State<_PageCard> {
  bool _isEditingKeyword = false;
  bool _isSaving = false;
  late TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.page.primaryKeyword ?? '');
  }

  @override
  void didUpdateWidget(_PageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.primaryKeyword != widget.page.primaryKeyword) {
      _keywordController.text = widget.page.primaryKeyword ?? '';
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _saveKeyword() async {
    setState(() => _isSaving = true);
    final keyword = _keywordController.text.trim();
    await widget.onKeywordUpdated(keyword.isEmpty ? null : keyword);
    setState(() {
      _isSaving = false;
      _isEditingKeyword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
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
                Chip(
                  label: Text(
                    '${page.httpStatus ?? '?'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: statusColor.withOpacity(0.2),
                  side: BorderSide(color: statusColor),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    page.url,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // SEO elements table
            Table(
              columnWidths: const {
                0: FixedColumnWidth(100),
                1: FlexColumnWidth(),
              },
              children: [
                _buildTableRow(context, 'Title', page.title, page.title != null, page.keywordInTitle),
                _buildTableRow(context, 'Meta', page.metaDescription, page.metaDescription != null, page.keywordInMeta),
                _buildTableRow(context, 'H1', page.h1, page.h1 != null, page.keywordInH1),
                _buildTableRow(context, 'Canonical', page.canonicalUrl, page.canonicalUrl != null, false),
              ],
            ),
            // Suggestion count row
            if (widget.suggestionCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.suggestionCount} open suggestion${widget.suggestionCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            // Primary keyword section
            _buildKeywordSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordSection(BuildContext context) {
    final page = widget.page;

    if (_isEditingKeyword) {
      return Row(
        children: [
          Icon(Icons.key, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                hintText: 'Enter primary keyword...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              autofocus: true,
              onSubmitted: (_) => _saveKeyword(),
            ),
          ),
          const SizedBox(width: 8),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check, size: 20),
              onPressed: _saveKeyword,
              color: Colors.green,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                setState(() {
                  _isEditingKeyword = false;
                  _keywordController.text = page.primaryKeyword ?? '';
                });
              },
              color: Colors.grey,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      );
    }

    return InkWell(
      onTap: () => setState(() => _isEditingKeyword = true),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.key,
              size: 16,
              color: page.hasPrimaryKeyword ? Colors.blue : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: page.hasPrimaryKeyword
                  ? Row(
                      children: [
                        Text(
                          page.primaryKeyword!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Keyword alignment badges
                        _KeywordBadge(label: 'T', present: page.keywordInTitle),
                        const SizedBox(width: 4),
                        _KeywordBadge(label: 'M', present: page.keywordInMeta),
                        const SizedBox(width: 4),
                        _KeywordBadge(label: 'H1', present: page.keywordInH1),
                      ],
                    )
                  : Text(
                      'Set primary keyword...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
            Icon(Icons.edit, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(BuildContext context, String label, String? value, bool present, bool hasKeyword) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                present ? Icons.check : Icons.close,
                size: 14,
                color: present ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              if (widget.page.hasPrimaryKeyword && label != 'Canonical') ...[
                const SizedBox(width: 4),
                Icon(
                  hasKeyword ? Icons.key : Icons.key_off,
                  size: 12,
                  color: hasKeyword ? Colors.blue : Colors.grey[400],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value ?? '—',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: present ? null : Colors.grey,
                  fontStyle: present ? null : FontStyle.italic,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _KeywordBadge extends StatelessWidget {
  final String label;
  final bool present;

  const _KeywordBadge({required this.label, required this.present});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: present ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: present ? Colors.green : Colors.grey,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: present ? Colors.green[700] : Colors.grey[600],
        ),
      ),
    );
  }
}

// ============================================================================
// REDIRECTS LENS - Status, redirect chain, redirect plan
// ============================================================================

class _RedirectsLens extends StatelessWidget {
  final Domain domain;
  final AsyncValue<DomainStatus?> statusAsync;
  final VoidCallback onRescan;
  final Future<void> Function(String?, String?) onRedirectPlanUpdate;

  const _RedirectsLens({
    required this.domain,
    required this.statusAsync,
    required this.onRescan,
    required this.onRedirectPlanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusSection(statusAsync: statusAsync),
          const SizedBox(height: 16),
          _RedirectPlanSection(
            domain: domain,
            statusAsync: statusAsync,
            onSave: onRedirectPlanUpdate,
            onRescan: onRescan,
          ),
        ],
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
                        'Click the scan button to check this domain',
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
                  const Text('Final URL:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(status.finalUrl!),
                  const SizedBox(height: 8),
                ],
                if (status.finalStatusCode != null) ...[
                  const Text('Status Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(status.finalStatusCode.toString()),
                  const SizedBox(height: 8),
                ],
                if (status.hasRedirects) ...[
                  const Text('Redirect Chain:', style: TextStyle(fontWeight: FontWeight.bold)),
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
    // Convert UTC to local time
    return DateFormat.yMMMd().add_jm().format(date.toLocal());
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
3. Navigate to Rules → Page Rules
4. Create a new rule matching $domainName/*
5. Set "Forwarding URL (301)" to $preferredUrl\$1
6. Save and deploy''';
      case 'Netlify':
        return '''Netlify setup:
1. In your site's root, create/edit _redirects file
2. Add this line:
   /*  $preferredUrl:splat  301!
3. Deploy your changes''';
      case 'Vercel':
        return '''Vercel setup:
1. Edit vercel.json in your project root
2. Add a redirect rule:
   {"redirects": [{"source": "/:path*", "destination": "$preferredUrl:path*", "permanent": true}]}
3. Deploy your changes''';
      default:
        return '''General redirect setup:
1. Access your DNS or hosting provider's dashboard
2. Look for "Redirects", "Forwarding", or "Page Rules"
3. Create a 301 redirect from $domainName to $preferredUrl
4. Save changes and wait for propagation''';
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
            Text('Redirect Plan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
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
                                'Current destination does not match preferred URL',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Current: ${status?.finalUrl ?? "Unknown"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(onPressed: widget.onRescan, child: const Text('Rescan')),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Preferred URL',
                border: OutlineInputBorder(),
                hintText: 'https://www.your-primary-site.com/',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(labelText: 'Redirect Provider', border: OutlineInputBorder()),
              items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => _selectedProvider = value),
              hint: const Text('Select your provider'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Redirect Plan'),
              ),
            ),
            if (_selectedProvider != null && _urlController.text.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Text('Setup Instructions', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: SelectableText(
                  _getProviderInstructions(_selectedProvider),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UPTIME LENS - Uptime monitoring and response time
// ============================================================================

class _UptimeLens extends StatefulWidget {
  final Domain domain;
  final Future<void> Function(bool enabled, int interval) onUptimeSettingsUpdate;

  const _UptimeLens({
    required this.domain,
    required this.onUptimeSettingsUpdate,
  });

  @override
  State<_UptimeLens> createState() => _UptimeLensState();
}

class _UptimeLensState extends State<_UptimeLens> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final domain = widget.domain;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _UptimeStatusCard(domain: domain),
          const SizedBox(height: 16),

          // Settings card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Uptime Monitoring Settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable uptime monitoring'),
                    subtitle: Text(
                      domain.uptimeEnabled
                          ? 'Checking every ${domain.uptimeCheckIntervalMinutes} minutes'
                          : 'Turn on to monitor if your site is up',
                    ),
                    value: domain.uptimeEnabled,
                    onChanged: _isUpdating
                        ? null
                        : (value) async {
                            setState(() => _isUpdating = true);
                            await widget.onUptimeSettingsUpdate(
                              value,
                              domain.uptimeCheckIntervalMinutes,
                            );
                            setState(() => _isUpdating = false);
                          },
                  ),
                  if (domain.uptimeEnabled) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Check interval:'),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5 min')),
                        ButtonSegment(value: 10, label: Text('10 min')),
                        ButtonSegment(value: 30, label: Text('30 min')),
                      ],
                      selected: {domain.uptimeCheckIntervalMinutes},
                      onSelectionChanged: _isUpdating
                          ? null
                          : (values) async {
                              setState(() => _isUpdating = true);
                              await widget.onUptimeSettingsUpdate(
                                true,
                                values.first,
                              );
                              setState(() => _isUpdating = false);
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metrics cards
          if (domain.uptimeEnabled && domain.lastUptimeCheckedAt != null) ...[
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.trending_up,
                    label: '24h Uptime',
                    value: domain.uptime24hPercent != null
                        ? '${domain.uptime24hPercent!.toStringAsFixed(1)}%'
                        : '--',
                    color: _getUptimeColor(domain.uptime24hPercent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.calendar_today,
                    label: '7d Uptime',
                    value: domain.uptime7dPercent != null
                        ? '${domain.uptime7dPercent!.toStringAsFixed(1)}%'
                        : '--',
                    color: _getUptimeColor(domain.uptime7dPercent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.speed,
                    label: 'Response Time',
                    value: domain.formattedResponseTime ?? '--',
                    color: _getResponseTimeColor(domain.lastResponseTimeMs),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.access_time,
                    label: 'Last Check',
                    value: domain.timeSinceLastUptimeCheck ?? '--',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],

          // Info text
          const SizedBox(height: 24),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Uptime monitoring checks if https://${domain.domainName} is reachable and measures response time.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getUptimeColor(double? percent) {
    if (percent == null) return Colors.grey;
    if (percent >= 99) return Colors.green;
    if (percent >= 95) return Colors.orange;
    return Colors.red;
  }

  Color _getResponseTimeColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 500) return Colors.green;
    if (ms < 1500) return Colors.orange;
    return Colors.red;
  }
}

class _UptimeStatusCard extends StatelessWidget {
  final Domain domain;

  const _UptimeStatusCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    if (!domain.uptimeEnabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'Uptime monitoring is disabled',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Enable it to track if your site is up',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final isUp = domain.isUp;
    final statusColor = domain.lastUptimeStatus == null
        ? Colors.blue
        : isUp
            ? Colors.green
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: domain.lastUptimeStatus == null
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isUp ? Icons.check_circle : Icons.error,
                      color: statusColor,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain.lastUptimeStatus == null
                        ? 'Waiting for first check...'
                        : isUp
                            ? 'Site is UP'
                            : 'Site is DOWN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (domain.lastUptimeCheckedAt != null)
                    Text(
                      'Last checked ${domain.timeSinceLastUptimeCheck}${domain.lastResponseTimeMs != null ? ' • ${domain.formattedResponseTime}' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    )
                  else
                    Text(
                      'Checks run every ${domain.uptimeCheckIntervalMinutes} min. First check coming soon.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXPIRY LENS - WHOIS info, expiry, notes
// ============================================================================

class _ExpiryLens extends StatelessWidget {
  final Domain domain;
  final bool whoisEnabled;
  final Future<void> Function() onWhoisFetch;
  final VoidCallback onWhoisUpgrade;
  final Future<void> Function(String?, DateTime?) onDomainInfoUpdate;
  final Future<void> Function(String) onNotesUpdated;

  const _ExpiryLens({
    required this.domain,
    required this.whoisEnabled,
    required this.onWhoisFetch,
    required this.onWhoisUpgrade,
    required this.onDomainInfoUpdate,
    required this.onNotesUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DomainInfoSection(
            domain: domain,
            onWhoisFetch: onWhoisFetch,
            onWhoisUpgrade: onWhoisUpgrade,
            whoisEnabled: whoisEnabled,
            onManualUpdate: onDomainInfoUpdate,
          ),
          const SizedBox(height: 16),
          _ExpiryWarningCard(domain: domain),
          const SizedBox(height: 16),
          _NotesSection(domain: domain, onSave: onNotesUpdated),
        ],
      ),
    );
  }
}

class _ExpiryWarningCard extends StatelessWidget {
  final Domain domain;

  const _ExpiryWarningCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    if (domain.expiryDate == null) {
      return const SizedBox.shrink();
    }

    final daysUntilExpiry = domain.expiryDate!.difference(DateTime.now()).inDays;
    final isExpired = domain.isExpired;
    final expiresSoon = domain.expiresWithinDays(30);

    if (!isExpired && !expiresSoon) {
      return Card(
        color: Colors.green.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Domain is secure', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Expires in $daysUntilExpiry days'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.error : Icons.warning,
              color: isExpired ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired ? 'Domain has expired!' : 'Domain expires soon!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.red : Colors.orange,
                    ),
                  ),
                  Text(isExpired ? 'Renew immediately to avoid losing this domain' : 'Expires in $daysUntilExpiry days'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainInfoSection extends StatefulWidget {
  final Domain domain;
  final Future<void> Function() onWhoisFetch;
  final VoidCallback onWhoisUpgrade;
  final bool whoisEnabled;
  final Future<void> Function(String?, DateTime?) onManualUpdate;

  const _DomainInfoSection({
    required this.domain,
    required this.onWhoisFetch,
    required this.onWhoisUpgrade,
    required this.whoisEnabled,
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
                Text('Domain Info', style: Theme.of(context).textTheme.titleMedium),
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
                  decoration: const InputDecoration(labelText: 'Expiry Date', border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedExpiry != null ? DateFormat.yMMMd().format(_selectedExpiry!) : 'Select date'),
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
                  FilledButton(onPressed: _saveManual, child: const Text('Save')),
                ],
              ),
            ] else ...[
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
                value: widget.domain.expiryDate != null ? DateFormat.yMMMd().format(widget.domain.expiryDate!) : 'Unknown',
                isUnknown: widget.domain.expiryDate == null,
                warning: expiryWarning,
                error: isExpired,
                warningText: isExpired ? 'Expired!' : 'Expires soon',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: widget.whoisEnabled
                    ? OutlinedButton.icon(
                        onPressed: _isLoading ? null : _fetchWhois,
                        icon: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: Text(_isLoading ? 'Fetching...' : 'Fetch from WHOIS'),
                      )
                    : OutlinedButton(
                        onPressed: () => widget.onWhoisUpgrade(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock, size: 18),
                            const SizedBox(width: 8),
                            const Text('Fetch from WHOIS'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Pro',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
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
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
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
                      border: Border.all(color: error ? Colors.red : Colors.orange),
                    ),
                    child: Text(
                      warningText ?? 'Warning',
                      style: TextStyle(fontSize: 11, color: error ? Colors.red : Colors.orange, fontWeight: FontWeight.w500),
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

class _NotesSection extends StatefulWidget {
  final Domain domain;
  final Future<void> Function(String) onSave;

  const _NotesSection({required this.domain, required this.onSave});

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
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
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
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Add notes about this domain...'),
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
                _controller.text.isEmpty ? 'No notes yet' : _controller.text,
                style: _controller.text.isEmpty
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)
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
// WHOIS UPGRADE OPTION
// ============================================================================

class _WhoisUpgradeOption extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool highlighted;
  final VoidCallback onTap;

  const _WhoisUpgradeOption({
    required this.title,
    required this.price,
    this.badge,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(price, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
