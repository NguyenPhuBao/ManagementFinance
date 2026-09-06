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
        syncRetryCount: 0,
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

  group('Chuẩn hoá tiếng Việt', () {
    test('Gộp NFC: hai cách gõ cùng một chữ phải khớp nhau', () {
      final coffee = category(id: 'coffee');

      // 'cà phê' dạng tách dấu (NFD): chữ cái trần + dấu thanh rời. Nhìn bằng
      // mắt giống hệt dạng dựng sẵn, nhưng khác byte và khác cả độ dài chuỗi.
      const nfd = 'cà phê';

      expect(
        engine.suggest(
          rawText: 'Sáng $nfd ở quán',
          candidates: [
            CategoryKeywordCandidate(category: coffee, keyword: 'cà phê'),
          ],
        )?.categoryId,
        'coffee',
        reason: 'Bàn phím iOS và một số bộ gõ Android sinh ra dạng tách dấu. '
            'Không gộp NFC thì từ khoá người dùng lưu từ máy này không khớp ghi '
            'chú gõ trên máy kia — hỏng âm thầm, đúng lý do '
            '`normalizeCategoryName` bắt buộc bước NFC.',
      );
    });

    test('Bỏ dấu là đường DỰ PHÒNG khi không có gì khớp còn dấu', () {
      final coffee = category(id: 'coffee');

      expect(
        engine.suggest(
          rawText: 'sang ca phe voi ban',
          candidates: [
            CategoryKeywordCandidate(category: coffee, keyword: 'cà phê'),
          ],
        )?.categoryId,
        'coffee',
        reason: 'Người dùng gõ nhanh thường bỏ dấu. Backend cũng so cả hai '
            'dạng (`keyword.matcher.js` giữ nhánh `cleanNoTone`), nên client '
            'không làm thì hai phía cho kết quả khác nhau trên cùng một ghi chú.',
      );
    });

    test('Khớp CÒN DẤU luôn thắng khớp bỏ dấu', () {
      final da = category(id: 'do_uong'); // "đá"
      final leather = category(id: 'thoi_trang'); // "da"

      final result = engine.suggest(
        rawText: 'mua áo da',
        candidates: [
          CategoryKeywordCandidate(category: da, keyword: 'đá'),
          CategoryKeywordCandidate(category: leather, keyword: 'da'),
        ],
      );

      expect(
        result?.categoryId,
        'thoi_trang',
        reason: 'Bỏ dấu làm "đá" và "da" thành một. Nếu chạy hai phép so cùng '
            'lúc thì hai danh mục hoà nhau và engine trả null — người dùng mất '
            'gợi ý đúng vì một từ khoá không liên quan. Vì vậy vòng bỏ dấu chỉ '
            'chạy KHI vòng còn dấu không tìm được gì.',
      );
    });

    test('Bỏ dấu vẫn giữ nguyên luật hoà thì không đoán', () {
      expect(
        engine.suggest(
          rawText: 'an com',
          candidates: [
            CategoryKeywordCandidate(category: category(id: 'a'), keyword: 'ăn cơm'),
            CategoryKeywordCandidate(category: category(id: 'b'), keyword: 'ăn cơm'),
          ],
        ),
        isNull,
        reason: 'Luật "hoà thì không đoán" phải áp dụng cho cả vòng dự phòng. '
            'Đoán bừa ở đây tệ hơn không gợi ý: người dùng tin thẻ gợi ý và '
            'lưu nhầm danh mục mà không kiểm lại.',
      );
    });
  });
}
