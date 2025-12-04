// lib/ui/screens/report/public_report_screen.dart
// Public read-only report screen

import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../data/models/report_data.dart';
import '../../../data/providers.dart';

class PublicReportScreen extends ConsumerWidget {
  final String token;

  const PublicReportScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(publicReportProvider(token));

    return Scaffold(
      body: reportAsync.when(
        data: (report) => _ReportContent(report: report, ref: ref),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading report...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Report Not Available',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'This report may have been disabled or the link is invalid.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => launchUrlString('https://seolens.io'),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to SEO Lens'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final ReportData report;
  final WidgetRef ref;

  const _ReportContent({required this.report, required this.ref});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo and title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.language, size: 32, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'SEO Lens Report',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.domain.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                if (report.domain.lastScannedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last scanned: ${DateFormat.yMMMd().add_jm().format(report.domain.lastScannedAt!.toLocal())}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Summary Cards
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SummarySection(report: report),
          ),
        ),

        // Health Breakdown
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _HealthBreakdown(report: report),
          ),
        ),

        // Issues Section
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _IssuesSection(report: report),
          ),
        ),

        // Pages Section
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _PagesSection(report: report),
          ),
        ),

        // Referral CTA
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _ReferralCta(report: report, ref: ref),
          ),
        ),

        // Footer
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey[50],
            child: Column(
              children: [
                Text(
                  'Report generated by SEO Lens',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => launchUrlString('https://seolens.io'),
                  child: const Text('seolens.io'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  final ReportData report;

  const _SummarySection({required this.report});

  @override
  Widget build(BuildContext context) {
    final domain = report.domain;
    final healthScore = domain.healthScore ?? 0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _StatCard(
          title: 'Health Score',
          value: '$healthScore',
          color: healthScore >= 80
              ? Colors.green
              : healthScore >= 60
                  ? Colors.orange
                  : Colors.red,
          icon: Icons.favorite,
        ),
        _StatCard(
          title: 'Pages Scanned',
          value: '${domain.totalPagesScanned ?? 0}',
          color: Colors.blue,
          icon: Icons.article,
        ),
        _StatCard(
          title: 'Issues Found',
          value: '${report.suggestions.length}',
          color: report.suggestions.isNotEmpty ? Colors.orange : Colors.green,
          icon: Icons.warning_amber,
        ),
        if (domain.uptime24hPercent != null)
          _StatCard(
            title: 'Uptime (24h)',
            value: '${domain.uptime24hPercent!.toStringAsFixed(1)}%',
            color: domain.uptime24hPercent! >= 99 ? Colors.green : Colors.orange,
            icon: Icons.signal_cellular_alt,
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthBreakdown extends StatelessWidget {
  final ReportData report;

  const _HealthBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    final domain = report.domain;
    final total = domain.totalPagesScanned ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _BreakdownRow(
              label: 'Pages with Title',
              value: total - (domain.pagesMissingTitle ?? 0),
              total: total,
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              label: 'Pages with Meta Description',
              value: total - (domain.pagesMissingMeta ?? 0),
              total: total,
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              label: 'Pages with H1',
              value: total - (domain.pagesMissingH1 ?? 0),
              total: total,
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              label: 'Successful Responses (2xx)',
              value: domain.pages2xx ?? 0,
              total: total,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? value / total : 1.0;
    final color = percentage >= 0.8
        ? Colors.green
        : percentage >= 0.6
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text(
            '$value/$total',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _IssuesSection extends StatelessWidget {
  final ReportData report;

  const _IssuesSection({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.suggestions.isEmpty) {
      return Card(
        color: Colors.green[50],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text(
                'No issues found!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groupedSuggestions = report.suggestionsByType;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Issues Found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${report.suggestions.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...groupedSuggestions.entries.map((entry) {
              final typeName = entry.value.first.typeName;
              final count = entry.value.length;
              final severity = entry.value.first.severity ?? 'medium';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: severity == 'high'
                            ? Colors.red
                            : severity == 'medium'
                                ? Colors.orange
                                : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(typeName),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PagesSection extends StatelessWidget {
  final ReportData report;

  const _PagesSection({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.pages.isEmpty) {
      return const SizedBox.shrink();
    }

    final pagesToShow = report.pages.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pages Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Path')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Issues')),
                ],
                rows: pagesToShow.map((page) {
                  return DataRow(cells: [
                    DataCell(Text(
                      page.path,
                      style: const TextStyle(fontFamily: 'monospace'),
                    )),
                    DataCell(SizedBox(
                      width: 200,
                      child: Text(
                        page.title ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    DataCell(Text(
                      '${page.statusCode ?? '-'}',
                      style: TextStyle(
                        color: page.isError ? Colors.red : null,
                      ),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: page.hasIssues ? Colors.orange[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${page.issueCount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: page.hasIssues ? Colors.orange[800] : Colors.green[800],
                          fontSize: 12,
                        ),
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
            if (report.pages.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '... and ${report.pages.length - 10} more pages',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCta extends StatelessWidget {
  final ReportData report;
  final WidgetRef ref;

  const _ReferralCta({required this.report, required this.ref});

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final pdfService = ref.read(reportPdfServiceProvider);
      final bytes = await pdfService.buildReportPdf(report);

      // Trigger download in web
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${report.domain.domainName.replaceAll('.', '-')}-seo-report.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralUrl = report.owner.referralSignupUrl ?? 'https://seolens.io/app';

    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.analytics,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Get your own SEO Lens report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This report was generated by SEO Lens. Scan your own domains, track uptime, and fix SEO issues in one cockpit.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (report.owner.referralCode != null)
              Text(
                'This link supports the owner of this report:',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[500],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => launchUrlString(referralUrl),
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('Get started free with SEO Lens'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadPdf(context),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
