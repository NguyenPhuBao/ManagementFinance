import '../models/category_suggestion.dart';
import '../../../../core/database/app_database.dart';

class CategorySuggestionEngine {
  const CategorySuggestionEngine();

  CategorySuggestion? suggest({
    required String rawText,
    required Iterable<CategoryKeywordCandidate> candidates,
  }) {
    final normalizedText = _normalize(rawText);
    if (normalizedText.isEmpty) return null;

    final matchesByCategory = <String, _CandidateMatch>{};
    for (final candidate in candidates) {
      final keyword = _normalize(candidate.keyword);
      if (candidate.category.isDeleted ||
          candidate.category.isGroup ||
          keyword.isEmpty ||
          !normalizedText.contains(keyword)) {
        continue;
      }

      final current = matchesByCategory[candidate.category.id];
      if (current == null) {
        matchesByCategory[candidate.category.id] = _CandidateMatch(
          category: candidate.category,
          keywords: {keyword},
        );
      } else {
        current.keywords.add(keyword);
      }
    }

    if (matchesByCategory.isEmpty) return null;
    final ranked = matchesByCategory.values.toList()
      ..sort((left, right) {
        final count = right.keywords.length.compareTo(left.keywords.length);
        if (count != 0) return count;
        return right.longestKeyword.length
            .compareTo(left.longestKeyword.length);
      });
    final winner = ranked.first;
    if (ranked.length > 1 &&
        ranked[1].keywords.length == winner.keywords.length &&
        ranked[1].longestKeyword.length == winner.longestKeyword.length) {
      return null;
    }

    return CategorySuggestion(
      category: winner.category,
      matchedKeyword: winner.longestKeyword,
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _CandidateMatch {
  _CandidateMatch({required this.category, required this.keywords});

  final Category category;
  final Set<String> keywords;

  String get longestKeyword {
    return keywords.reduce(
      (longest, keyword) => keyword.length > longest.length ? keyword : longest,
    );
  }
}
