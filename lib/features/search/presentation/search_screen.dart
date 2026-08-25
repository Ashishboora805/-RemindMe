import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../services/search_service.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final resultsAsync = ref.watch(searchResultsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Search')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: CupertinoSearchTextField(
                  controller: _ctrl,
                  autofocus: true,
                  placeholder: 'Search everything',
                  onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                ),
              ),
              Expanded(
                child: resultsAsync.when(
                  data: (results) {
                    if (ref.watch(searchQueryProvider).isEmpty) {
                      return Center(
                        child: Text('Search projects, notes, tags, and reminders',
                            style: TextStyle(color: AppColors.textSecondary(brightness))),
                      );
                    }
                    if (results.isEmpty) {
                      return Center(
                        child: Text('No results',
                            style: TextStyle(color: AppColors.textSecondary(brightness))),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final r = results[i];
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          onTap: () => _openResult(context, r),
                          child: Row(
                            children: [
                              Icon(_iconFor(r.type), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (r.subtitle.isNotEmpty)
                                      Text(r.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary(brightness))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CupertinoActivityIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SearchResultType type) {
    switch (type) {
      case SearchResultType.project:
        return CupertinoIcons.folder_fill;
      case SearchResultType.note:
        return CupertinoIcons.doc_text;
      case SearchResultType.reminder:
        return CupertinoIcons.bell_fill;
    }
  }

  void _openResult(BuildContext context, SearchResult r) {
    switch (r.type) {
      case SearchResultType.project:
        context.push('/projects/${r.id}');
        break;
      case SearchResultType.note:
        context.push('/note/${r.id}');
        break;
      case SearchResultType.reminder:
        context.push('/reminder/${r.id}');
        break;
    }
  }
}
