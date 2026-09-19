/// Không tệp nào trong `lib/` được tự ghép ký hiệu `đ` vào con số — test quét
/// `lib/` thứ **mười một** (2026-09-19, UX B3/B4).
///
/// `currency_formatter_test` đã cấm dựng `NumberFormat` ngoài `CurrencyFormatter`,
/// nhưng cấm ấy lọt một lối đi vòng: gọi `formatSoThoi()` (số không kèm ký
/// hiệu) rồi nối `'đ'` bằng tay. Lượt đánh giá UX 2026-09-19 đếm được **11**
/// chỗ như vậy, và hệ quả nhìn thấy trên máy ảo: Trang chủ, Sổ giao dịch, màn
/// Thêm giao dịch và Phân tích viết *"13.590.000đ"* trong khi Ví, Ngân sách,
/// Mục tiêu, Hoá đơn và tệp xuất viết *"13.590.000 đ"* — hai quy ước trong
/// cùng một app, và không quy ước nào có chỗ để đổi cho cả app.
///
/// Luật: chữ `đ` đứng ngay sau một chữ số hoặc sau `}` của phép nội suy, bên
/// trong chuỗi, là vi phạm. Ký hiệu đứng **một mình** làm nhãn đơn vị cạnh ô
/// nhập (`suffixText: 'đ'`, `Text('đ')`) thì được — đó là đơn vị, không phải
/// con số đã định dạng. Chuỗi cố định trong màn mockup cũng phải liệt kê tay.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Tệp còn được phép, kèm số chỗ và lý do — cùng khuôn `khong_co_nut_chet_test`.
  const choChot = <String, (int, String)>{
    'features/ai_chat/presentation/pages/ai_chat_page.dart': (
      1,
      'Màn mockup tĩnh "3.200.000đ"; giữ hay gỡ là mục D9 của danh sách UX '
          '2026-09-19, chờ chốt.',
    ),
    'features/bill/presentation/pages/bill_delete_page.dart': (
      1,
      'Chuỗi cố định "260.000đ" trong một màn mockup không nối vào router — '
          'xoá hay dùng thật chờ chốt cùng lượt dọn màn chết.',
    ),
  };

  // `đ` ngay sau chữ số, sau `}` (kết thúc nội suy có ngoặc), hoặc sau một
  // nội suy trần `$ten` — Dart chỉ nhận ASCII trong định danh nên `'$moneyđ'`
  // là `$money` rồi `đ`, và chính `transaction_row_content.dart` viết thế.
  // Bỏ dòng chú thích: tài liệu trong mã có quyền nhắc tới "2.900.000đ".
  final khuon = RegExp(r'''(?:[0-9}]|\$[A-Za-z_][A-Za-z0-9_]*)đ''');

  test('không tệp nào trong lib/ tự nối "đ" vào con số', () {
    final thay = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final duong =
          f.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^lib/'), '');
      if (duong == 'core/utils/currency_formatter.dart') continue;
      var n = 0;
      for (final dong in f.readAsLinesSync()) {
        final t = dong.trimLeft();
        if (t.startsWith('//')) continue;
        // Log gỡ lỗi không phải giao diện.
        if (t.contains('debugPrint(')) continue;
        n += khuon.allMatches(dong).length;
      }
      if (n > 0) thay[duong] = n;
    }

    final loi = <String>[];
    for (final e in thay.entries) {
      final cho = choChot[e.key];
      if (cho == null) {
        loi.add('${e.key}: ${e.value} chỗ nối "đ" tay — dùng '
            'CurrencyFormatter.format / formatCoDau.');
      } else if (cho.$1 != e.value) {
        loi.add('${e.key}: có ${e.value} chỗ nhưng danh sách ghi ${cho.$1}.');
      }
    }
    for (final e in choChot.entries) {
      if (!thay.containsKey(e.key)) {
        loi.add('${e.key}: danh sách còn ghi nhưng tệp đã sạch — rút ra.');
      }
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
