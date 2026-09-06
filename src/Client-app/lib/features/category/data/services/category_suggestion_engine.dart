import '../models/category_suggestion.dart';
import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';

class CategorySuggestionEngine {
  const CategorySuggestionEngine();

  CategorySuggestion? suggest({
    required String rawText,
    required Iterable<CategoryKeywordCandidate> candidates,
  }) {
    final normalizedText = normalizeCategoryName(rawText);
    if (normalizedText.isEmpty) return null;

    // Vòng 1 — so khớp CÒN DẤU. Đây là phép so chính xác hơn, nên nó phải được
    // xét trước và thắng tuyệt đối.
    final conDau = _timUngVien(
      text: normalizedText,
      candidates: candidates,
      bienDoi: (value) => value,
    );
    if (conDau != null) return conDau;

    // Vòng 2 — dự phòng, so khớp BỎ DẤU. Người dùng gõ nhanh thường bỏ dấu
    // ("sang ca phe"), và backend cũng so cả hai dạng (`keyword.matcher.js` giữ
    // nhánh `cleanNoTone`), nên không có vòng này thì hai phía cho kết quả khác
    // nhau trên cùng một ghi chú.
    //
    // Cố ý KHÔNG gộp hai vòng làm một: bỏ dấu là phép so mất thông tin — "đá"
    // và "da" thành một — nên chạy song song sẽ tạo ra những cặp hoà giả, và
    // luật "hoà thì không đoán" sẽ nuốt mất cả gợi ý đúng.
    return _timUngVien(
      text: removeVietnameseTones(normalizedText),
      candidates: candidates,
      bienDoi: removeVietnameseTones,
    );
  }

  CategorySuggestion? _timUngVien({
    required String text,
    required Iterable<CategoryKeywordCandidate> candidates,
    required String Function(String) bienDoi,
  }) {
    final matchesByCategory = <String, _CandidateMatch>{};
    for (final candidate in candidates) {
      final keyword = bienDoi(normalizeCategoryName(candidate.keyword));
      if (candidate.category.isDeleted ||
          candidate.category.isGroup ||
          keyword.isEmpty ||
          !text.contains(keyword)) {
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
    // Hoà thì KHÔNG đoán. Đoán bừa tệ hơn im lặng: người dùng tin thẻ gợi ý và
    // lưu nhầm danh mục mà không kiểm lại.
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
