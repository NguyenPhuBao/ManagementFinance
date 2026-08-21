import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';

void main() {
  const engine = CategorySuggestionEngine();
  final now = DateTime(2026, 8, 21);

  Category category({
    required String id,
    bool isGroup = false,
    bool isDeleted = false,
  }) =>
      Category(
        id: id,
        idaccount: 1,
        name: id,
        classify: 'chi',
        icon: 'category',
        colour: '#4CAF50',
        isDefault: false,
        isDeleted: isDeleted,
        isGroup: isGroup,
        isLocalOnly: true,
        syncStatus: 'pending',
        updatedAt: now,
      );

  test('normalizes whitespace and case before matching', () {
    final delivery = category(id: 'delivery');

    final result = engine.suggest(
      rawText: '  Thanh  toan   GRABFOOD ',
      candidates: [
        CategoryKeywordCandidate(category: delivery, keyword: ' grabfood '),
      ],
    );

    expect(result?.categoryId, 'delivery');
    expect(result?.matchedKeyword, 'grabfood');
  });

  test('ranks by matching keyword count then longest matching keyword', () {
    final delivery = category(id: 'delivery');
    final lunch = category(id: 'lunch');
    final taxi = category(id: 'taxi');

    final result = engine.suggest(
      rawText: 'Thanh toán GrabFood bằng delivery service taxi',
      candidates: [
        CategoryKeywordCandidate(category: lunch, keyword: 'trưa'),
        CategoryKeywordCandidate(category: delivery, keyword: 'grabfood'),
        CategoryKeywordCandidate(
            category: delivery, keyword: 'delivery service'),
        CategoryKeywordCandidate(category: taxi, keyword: 'taxi'),
      ],
    );

    expect(result?.categoryId, 'delivery');
    expect(result?.matchedKeyword, 'delivery service');
  });

  test('returns null for a remaining tie or ineligible candidates', () {
    final coffee = category(id: 'coffee');
    final cafe = category(id: 'cafe');

    expect(
      engine.suggest(
        rawText: 'cafe',
        candidates: [
          CategoryKeywordCandidate(category: coffee, keyword: 'cafe'),
          CategoryKeywordCandidate(category: cafe, keyword: 'cafe'),
        ],
      ),
      isNull,
    );
    expect(
      engine.suggest(
        rawText: 'cafe',
        candidates: [
          CategoryKeywordCandidate(
            category: category(id: 'group', isGroup: true),
            keyword: 'cafe',
          ),
          CategoryKeywordCandidate(
            category: category(id: 'deleted', isDeleted: true),
            keyword: 'cafe',
          ),
          CategoryKeywordCandidate(category: coffee, keyword: ' '),
        ],
      ),
      isNull,
    );
  });
}
