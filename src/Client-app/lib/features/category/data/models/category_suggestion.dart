import '../../../../core/database/app_database.dart';

class CategorySuggestion {
  const CategorySuggestion({
    required this.category,
    required this.matchedKeyword,
  });

  final Category category;
  final String matchedKeyword;

  String get categoryId => category.id;
}

class CategoryKeywordCandidate {
  const CategoryKeywordCandidate({
    required this.category,
    required this.keyword,
  });

  final Category category;
  final String keyword;
}
