import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../services/search_service.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(searchServiceProvider).searchAll(query);
});
