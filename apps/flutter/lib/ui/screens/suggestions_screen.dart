import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/suggestion.dart';
import '../../data/providers.dart';

/// Suggestions screen with domain and status filtering
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  SuggestionStatus? _statusFilter;
  String? _domainFilter; // Filter by domain ID
  String? _pageFilter; // Filter by page ID

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(_statusFilter == null
        ? suggestionsProvider
        : suggestionsByStatusProvider(_statusFilter));

    return Scaffold(
      body: Column(
        children: [
          // Status filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SingleChildScrollView(
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
                    label: const Text('Open'),
                    selected: _statusFilter == SuggestionStatus.open,
                    onSelected: (_) =>
                        setState(() => _statusFilter = SuggestionStatus.open),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('In Progress'),
                    selected: _statusFilter == SuggestionStatus.inProgress,
                    onSelected: (_) => setState(
                        () => _statusFilter = SuggestionStatus.inProgress),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Resolved'),
                    selected: _statusFilter == SuggestionStatus.resolved,
                    onSelected: (_) => setState(
                        () => _statusFilter = SuggestionStatus.resolved),
                  ),
                ],
              ),
            ),
          ),

          // Domain filter bar (built from suggestions data)
          suggestionsAsync.when(
            data: (suggestions) {
              // Get unique domains from suggestions
              final domainMap = <String, String>{};
              for (final s in suggestions) {
                if (s.domainId != null && s.domainName.isNotEmpty) {
                  domainMap[s.domainId!] = s.domainName;
                }
              }
              final domains = domainMap.entries.toList();

              if (domains.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(Icons.language, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All Domains'),
                        selected: _domainFilter == null,
                        onSelected: (_) => setState(() {
                          _domainFilter = null;
                          _pageFilter = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ...domains.map((d) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(d.value),
                              selected: _domainFilter == d.key,
                              onSelected: (_) => setState(() {
                                _domainFilter = d.key;
                                _pageFilter = null;
                              }),
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Active page filter indicator
          if (_pageFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Filtering by page',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Clear'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _pageFilter = null),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Suggestions list
          Expanded(
            child: suggestionsAsync.when(
              data: (suggestions) {
                // Apply domain and page filters
                var filtered = suggestions;
                if (_domainFilter != null) {
                  filtered = filtered
                      .where((s) => s.domainId == _domainFilter)
                      .toList();
                }
                if (_pageFilter != null) {
                  filtered =
                      filtered.where((s) => s.pageId == _pageFilter).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _statusFilter == null ||
                                  _statusFilter == SuggestionStatus.open
                              ? Icons.check_circle
                              : Icons.filter_list_off,
                          size: 64,
                          color: _statusFilter == null ||
                                  _statusFilter == SuggestionStatus.open
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _domainFilter != null || _pageFilter != null
                              ? 'No suggestions match these filters'
                              : _statusFilter == null
                                  ? 'No issues found'
                                  : _statusFilter == SuggestionStatus.open
                                      ? 'All clear! No open issues'
                                      : 'No ${_statusFilter!.label.toLowerCase()} suggestions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _domainFilter != null || _pageFilter != null
                              ? 'Try clearing the filters.'
                              : _statusFilter == null ||
                                      _statusFilter == SuggestionStatus.open
                                  ? 'Your domains are looking good!\nScan more domains to check for SEO issues.'
                                  : 'Try a different filter to see other suggestions.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final suggestion = filtered[index];
                    return SuggestionCard(
                      suggestion: suggestion,
                      showDomainLabel: true,
                      onStatusChanged: (status) async {
                        await ref
                            .read(suggestionServiceProvider)
                            .updateSuggestionStatus(
                              suggestionId: suggestion.id,
                              status: status,
                            );
                        ref.invalidate(suggestionsProvider);
                        ref.invalidate(
                            suggestionsByStatusProvider(_statusFilter));
                        ref.invalidate(suggestionCountsProvider);
                      },
                      onFilterByDomain: (domainId) {
                        setState(() {
                          _domainFilter = domainId;
                          _pageFilter = null;
                        });
                      },
                      onFilterByPage: (pageId) {
                        setState(() => _pageFilter = pageId);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable suggestion card widget with domain and page context
class SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final Function(SuggestionStatus) onStatusChanged;
  final bool showDomainLabel;
  final void Function(String domainId)? onFilterByDomain;
  final void Function(String pageId)? onFilterByPage;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.onStatusChanged,
    this.showDomainLabel = true,
    this.onFilterByDomain,
    this.onFilterByPage,
  });

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    switch (suggestion.severity) {
      case SuggestionSeverity.high:
        severityColor = Colors.red;
        break;
      case SuggestionSeverity.medium:
        severityColor = Colors.orange;
        break;
      case SuggestionSeverity.low:
        severityColor = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain and page context row
            _buildContextRow(context),

            const SizedBox(height: 8),

            // Severity, status, and menu row
            Row(
              children: [
                Chip(
                  label: Text(suggestion.severity.label),
                  backgroundColor: severityColor.withValues(alpha: 0.2),
                  side: BorderSide(color: severityColor),
                  avatar: Icon(
                    Icons.flag,
                    size: 16,
                    color: severityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(suggestion.status.label),
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
                const Spacer(),
                PopupMenuButton<SuggestionStatus>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: SuggestionStatus.open,
                      child: Text('Mark as Open'),
                    ),
                    const PopupMenuItem(
                      value: SuggestionStatus.inProgress,
                      child: Text('Mark as In Progress'),
                    ),
                    const PopupMenuItem(
                      value: SuggestionStatus.resolved,
                      child: Text('Mark as Resolved'),
                    ),
                    const PopupMenuItem(
                      value: SuggestionStatus.ignored,
                      child: Text('Ignore'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (suggestion.description != null) ...[
              const SizedBox(height: 4),
              Text(
                suggestion.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            // Show impact and effort badges
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(suggestion.impact.label),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                Chip(
                  label: Text(suggestion.effort.label),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the domain → page context row
  Widget _buildContextRow(BuildContext context) {
    final hasPage = suggestion.page != null;
    final hasDomain = suggestion.domainName.isNotEmpty;

    if (!showDomainLabel && !hasPage) {
      // Domain-level suggestion when domain label is hidden
      if (suggestion.effectiveScope == SuggestionScope.domain) {
        return Row(
          children: [
            Icon(Icons.language, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Domain-wide issue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Domain chip
        if (showDomainLabel && hasDomain)
          InkWell(
            onTap: onFilterByDomain != null && suggestion.domainId != null
                ? () => onFilterByDomain!(suggestion.domainId!)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Chip(
              label: Text(suggestion.domainName),
              avatar: const Icon(Icons.language, size: 14),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 12),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),

        // Arrow separator
        if (showDomainLabel && hasDomain && hasPage)
          Icon(Icons.arrow_forward_ios,
              size: 10, color: Colors.grey[500]),

        // Page chip
        if (hasPage)
          InkWell(
            onTap: onFilterByPage != null && suggestion.pageId != null
                ? () => onFilterByPage!(suggestion.pageId!)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Chip(
              label: Text(suggestion.page!.path),
              avatar: Icon(Icons.description_outlined,
                  size: 14, color: Theme.of(context).colorScheme.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3)),
            ),
          ),

        // Domain-wide indicator (when no page but showing domain)
        if (!hasPage &&
            showDomainLabel &&
            suggestion.effectiveScope == SuggestionScope.domain)
          Chip(
            label: const Text('Domain-wide'),
            avatar: Icon(Icons.public, size: 14, color: Colors.grey[600]),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
