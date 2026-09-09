/// Số tuần ISO — thêm 2026-09-09 cho thông báo Tổng kết tuần.
///
/// Dart **không có sẵn** phép này. Nó là khoá chống trùng của thông báo tuần,
/// nên sai một tuần nghĩa là hoặc báo hai lần cho cùng một tuần, hoặc bỏ sót
/// hẳn một tuần — cả hai đều **im lặng**.
///
/// Hai cái bẫy của ISO-8601, và cả hai đều là ca thật xảy ra mỗi năm:
///  1. Tuần vắt qua giao thừa thuộc về **đúng một** tuần ISO, không phải hai.
///  2. **Năm của tuần ISO không phải lúc nào cũng là `date.year`** — 31/12/2025
///     nằm trong tuần 1 của năm 2026, còn 01/01/2021 nằm trong tuần 53 của năm
///     2020.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/notification/tuan_iso.dart';

void main() {
  group('tuanISO', () {
    test('ngày giữa năm cho đúng tuần của chính năm ấy', () {
      // 09/09/2026 là thứ Tư.
      expect(tuanISO(DateTime(2026, 9, 9)), (nam: 2026, tuan: 37));
    });

    test('mọi ngày trong CÙNG một tuần cho cùng một khoá', () {
      // Thứ Hai 07/09/2026 → Chủ nhật 13/09/2026.
      final khoa = [
        for (var d = 7; d <= 13; d++) tuanISO(DateTime(2026, 9, d)),
      ];
      expect(
        khoa.toSet().length,
        1,
        reason: 'Khoá chống trùng dựng từ đây. Hai ngày cùng tuần ra hai khoá '
            'khác nhau là báo hai lần cho một tuần.',
      );
    });

    test('31/12/2025 thuộc tuần 1 của năm 2026, không phải tuần của 2025', () {
      expect(
        tuanISO(DateTime(2025, 12, 31)),
        (nam: 2026, tuan: 1),
        reason: 'Lấy `date.year` làm năm của tuần là chỗ sai kinh điển nhất. '
            'Nó đẻ ra khoá "2025-W01" cho một tuần đã mang khoá "2026-W01" — '
            'tức tuần ấy được báo hai lần, cách nhau đúng một lượt quét.',
      );
    });

    test('01/01/2021 thuộc tuần 53 của năm 2020', () {
      expect(
        tuanISO(DateTime(2021, 1, 1)),
        (nam: 2020, tuan: 53),
        reason: 'Chiều ngược lại của cùng cái bẫy: ngày đầu năm dương lịch có '
            'thể thuộc tuần cuối của năm trước. Và năm ISO có 53 tuần chứ '
            'không phải luôn 52 — kẹp về 52 là mất trọn một tuần.',
      );
    });

    test('04/01/2021 là thứ Hai của tuần 1 năm 2021', () {
      expect(tuanISO(DateTime(2021, 1, 4)), (nam: 2021, tuan: 1));
    });

    test('01/01/2024 rơi đúng thứ Hai nên là tuần 1 của 2024', () {
      expect(tuanISO(DateTime(2024, 1, 1)), (nam: 2024, tuan: 1));
    });

    test('năm nhuận: 29/02/2024 thuộc tuần 9', () {
      expect(
        tuanISO(DateTime(2024, 2, 29)),
        (nam: 2024, tuan: 9),
        reason: 'Phép đếm đi qua số thứ tự ngày trong năm, nên năm nhuận là ca '
            'phải phủ — dự án có quy ước ấy cho mọi logic ngày tháng.',
      );
    });

    test('giờ trong ngày không đổi kết quả', () {
      expect(
        tuanISO(DateTime(2026, 9, 9, 23, 59)),
        tuanISO(DateTime(2026, 9, 9, 0, 0)),
        reason: 'Khoá phải ổn định trong suốt một ngày, nếu không cùng một '
            'tuần ra hai khoá tuỳ giờ người dùng mở app.',
      );
    });
  });

  group('khoaTuan', () {
    test('số tuần một chữ số được đệm 0', () {
      expect(
        khoaTuan(DateTime(2024, 1, 1)),
        '2024-W01',
        reason: 'Không đệm thì "2024-W1" và "2024-W10" sắp xếp lẫn lộn, và ai '
            'đọc cột `dedupeKey` bằng mắt cũng phải đoán.',
      );
    });

    test('số tuần hai chữ số giữ nguyên', () {
      expect(khoaTuan(DateTime(2026, 9, 9)), '2026-W37');
    });

    test('khoá lấy NĂM ISO chứ không lấy năm dương lịch', () {
      expect(khoaTuan(DateTime(2025, 12, 31)), '2026-W01');
    });
  });

  group('tuanTruoc', () {
    test('trả về đúng thứ Hai 00:00 tới thứ Hai kế tiếp', () {
      // 09/09/2026 là thứ Tư; tuần liền trước là 31/08 → 07/09.
      final t = tuanTruoc(DateTime(2026, 9, 9, 15, 30));
      expect(t.from, DateTime(2026, 8, 31));
      expect(
        t.to,
        DateTime(2026, 9, 7),
        reason: 'Biên `to` là MỞ, cùng quy ước với mọi phép cắt khoảng khác '
            'trong app (`getExpenses`, `tongThuChi`). Lấy Chủ nhật 23:59:59 '
            'thì khoản ghi lúc 23:59:59.5 rơi ra ngoài mọi tuần.',
      );
    });

    test('đứng đúng thứ Hai thì tuần trước là bảy ngày ngay trước đó', () {
      final t = tuanTruoc(DateTime(2026, 9, 7, 8, 0));
      expect(t.from, DateTime(2026, 8, 31));
      expect(t.to, DateTime(2026, 9, 7));
    });

    test('đứng Chủ nhật thì tuần trước vẫn là tuần đã khép, không phải tuần này',
        () {
      // 13/09/2026 là Chủ nhật — vẫn thuộc tuần 07/09–14/09 đang chạy dở.
      final t = tuanTruoc(DateTime(2026, 9, 13, 22, 0));
      expect(
        t.from,
        DateTime(2026, 8, 31),
        reason: 'Chủ nhật vẫn nằm TRONG tuần hiện tại. Trả về tuần đang chạy '
            'là tổng kết một tuần chưa kết thúc.',
      );
      expect(t.to, DateTime(2026, 9, 7));
    });

    test('vắt qua giao thừa: tuần trước có thể nằm ở năm dương lịch khác', () {
      // 01/01/2026 là thứ Năm; tuần trước là 22/12/2025 → 29/12/2025.
      final t = tuanTruoc(DateTime(2026, 1, 1));
      expect(t.from, DateTime(2025, 12, 22));
      expect(t.to, DateTime(2025, 12, 29));
    });
  });
}
