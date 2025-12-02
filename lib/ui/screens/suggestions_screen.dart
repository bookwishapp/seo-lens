import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/suggestion.dart';
import '../../data/providers.dart';

/// Suggestions screen
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  SuggestionStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(_statusFilter == null
        ? suggestionsProvider
        : suggestionsByStatusProvider(_statusFilter));

    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
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

          // Suggestions list
          Expanded(
            child: suggestionsAsync.when(
              data: (suggestions) {
                if (suggestions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 64,
                            color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          _statusFilter == null
                              ? 'No suggestions yet'
                              : 'No ${_statusFilter!.label.toLowerCase()} suggestions',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      onStatusChanged: (status) async {
                        await ref
                            .read(suggestionServiceProvider)
                            .updateSuggestionStatus(
                              suggestionId: suggestion.id,
                              status: status,
                            );
                        ref.invalidate(suggestionsProvider);
                        ref.invalidate(suggestionsByStatusProvider(_statusFilter));
                        ref.invalidate(suggestionCountsProvider);
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

class _SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final Function(SuggestionStatus) onStatusChanged;

  const _SuggestionCard({
    required this.suggestion,
    required this.onStatusChanged,
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
            Row(
              children: [
                Chip(
                  label: Text(suggestion.severity.label),
                  backgroundColor: severityColor.withOpacity(0.2),
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
                  backgroundColor: Colors.grey.withOpacity(0.2),
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
            Text(
              'Type: ${suggestion.suggestionType}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
