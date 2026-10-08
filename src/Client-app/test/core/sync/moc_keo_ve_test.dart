import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/sync/moc_keo_ve.dart';

/// G67 — mốc kéo về lấy theo giờ-server (`maxSince`), không theo giờ ghi của máy.
void main() {
  // Giờ server lúc trả lời; mọi mốc "nguội" dưới đây đều cách nó > 2 phút.
  const pulledAt = '2026-10-08T12:00:00.000Z';

  group('mocTuMaxSince', () {
    test('không có maxSince / không phải Map / rỗng / rác → null (giữ mốc cũ)', () {
      expect(mocTuMaxSince(null, pulledAt: pulledAt), isNull);
      expect(mocTuMaxSince('2026-10-08T10:00:00.000Z', pulledAt: pulledAt), isNull);
      expect(mocTuMaxSince(const {}, pulledAt: pulledAt), isNull);
      expect(mocTuMaxSince(const {'wallet': null, 'goal': 'abc'}, pulledAt: pulledAt),
          isNull,
          reason: 'Không bảng nào có giờ đọc được thì không có gì để tiến mốc.');
    });

    test('⭐ lấy NHỎ NHẤT giữa các bảng, không phải lớn nhất', () {
      final moc = mocTuMaxSince(const {
        'wallet': '2026-10-08T10:00:00.000Z',
        'transaction': '2026-10-08T11:00:00.000Z',
      }, pulledAt: pulledAt);
      expect(moc, DateTime.utc(2026, 10, 8, 10, 0, 0, 1),
          reason: 'Server kéo từng bảng tuần tự. Một ví ghi lúc 10:30 — sau khi bảng '
              'ví đã truy vấn, trước khi bảng giao dịch truy vấn — không nằm trong '
              'phản hồi; lấy mốc 11:00 là bỏ sót nó vĩnh viễn (G67).');
      expect(moc!.isBefore(DateTime.utc(2026, 10, 8, 10, 30)), isTrue);
    });

    test('dữ liệu còn nóng → kẹp về pulledAt − 2 phút', () {
      final moc = mocTuMaxSince(const {
        'wallet': '2026-10-08T11:59:30.000Z',
      }, pulledAt: pulledAt);
      expect(moc, DateTime.utc(2026, 10, 8, 11, 58),
          reason: 'Hàng ghi trong lúc server đang kéo (ở bảng khác, hoặc commit '
              'muộn hơn giờ ghi) phải được hỏi lại ở lượt sau.');
    });

    test('đã nguội → cộng 1 ms để hàng cuối (giờ µs) thôi bị kéo lại mãi', () {
      final moc = mocTuMaxSince(const {
        'wallet': '2026-10-08T09:15:20.752Z',
      }, pulledAt: pulledAt);
      expect(moc, DateTime.utc(2026, 10, 8, 9, 15, 20, 753),
          reason: 'Server lưu 09:15:20.752xxx (µs), JSON chỉ mang .752; `gt .752` '
              'trả lại đúng hàng ấy ở mọi chu kỳ.');
    });

    test('cộng 1 ms không bao giờ vượt pulledAt − 2 phút', () {
      final moc = mocTuMaxSince(const {
        'wallet': '2026-10-08T11:58:00.000Z',
      }, pulledAt: pulledAt);
      expect(moc, DateTime.utc(2026, 10, 8, 11, 58));
    });

    test('không có pulledAt → dùng nguyên giá trị nhỏ nhất', () {
      expect(
          mocTuMaxSince(const {
            'wallet': '2026-10-08T10:00:00.000Z',
            'bill': '2026-10-08T09:00:00.000Z',
          }),
          DateTime.utc(2026, 10, 8, 9));
    });

    test('giờ có múi giờ khác vẫn quy về UTC trước khi so', () {
      final moc = mocTuMaxSince(const {
        'wallet': '2026-10-08T16:00:00.000+07:00', // = 09:00Z
        'goal': '2026-10-08T10:00:00.000Z',
      });
      expect(moc, DateTime.utc(2026, 10, 8, 9));
    });
  });
}
