/// Chiều tiền chỉ được gắn dấu ở MỘT chỗ — `CurrencyFormatter.formatCoDau`.
///
/// **Test quét `lib/` thứ mười bốn.** Sinh ra ngày 2026-09-21, sau khi cùng một
/// bẫy tái phát **ba lần**:
///
/// 1. Bảng "Phân bổ theo ví" (2026-09-15) — chỗ `formatCoDau` ra đời.
/// 2. Thẻ tổng trang **Sổ giao dịch** (2026-09-21, sáng).
/// 3. Thẻ tổng trang **Phân tích** (2026-09-21, chiều).
///
/// Cả ba đều do **máy ảo** bắt, không phải bộ test; và cả ba đều hỏng **im
/// lặng** — `-0 đ` là một chuỗi hợp lệ, không ngoại lệ nào được ném ra.
///
/// ## Vì sao cấm cả khuôn ba ngôi, không chỉ cấm `formatExpense`
///
/// `formatIncome` và `formatExpense` **luôn** gắn dấu, kể cả cho số 0, và
/// `+0 đ` / `-0 đ` đọc như một con số dương hoặc âm bằng không — vô nghĩa.
/// Khuôn `cond ? formatIncome(x) : formatExpense(x)` là **đúng nghĩa đen** của
/// `formatCoDau(x, thu: cond)`, chỉ khác đúng ở ca 0. Nên chỗ nào viết khuôn ấy
/// là chỗ ấy đang chờ tới lượt mình vấp.
///
/// ⚠️ Test quét ký hiệu tiền (`ky_hieu_tien_mot_noi_test.dart`) **không** bắt
/// được họ lỗi này: nó canh ký hiệu `đ`, không canh **dấu**.
///
/// ## Nếu có ngày cần gọi thẳng
///
/// Thêm tệp vào [_duocPhep] kèm **lý do**, và lý do ấy phải nói rõ vì sao số 0
/// **không thể** tới được chỗ đó. Đừng nới luật bằng cách xoá ca test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tệp được phép gọi thẳng `formatIncome` / `formatExpense`, kèm lý do.
const Map<String, String> _duocPhep = {
  // Chính nơi định nghĩa: `formatCoDau` uỷ quyền cho hai hàm này sau khi đã
  // tự chặn ca 0.
  'lib/core/utils/currency_formatter.dart': 'nơi định nghĩa',
};

/// Bỏ chú thích để một dòng chỉ *nhắc tên* hàm không bị tính là lời gọi —
/// nhiều tệp có chú thích dạng "dùng `formatCoDau` chứ không `formatIncome`".
String _boChuThich(String nguon) {
  final khongKhoi = nguon.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return khongKhoi
      .split('\n')
      .where((d) => !d.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  test('chỉ `formatCoDau` được gắn dấu theo chiều tiền', () {
    final viPham = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final duongDan = f.path.replaceAll(r'\', '/');
      if (_duocPhep.containsKey(duongDan)) continue;

      final noiDung = _boChuThich(f.readAsStringSync());
      if (!noiDung.contains('formatIncome') &&
          !noiDung.contains('formatExpense')) {
        continue;
      }

      for (final (i, dong) in noiDung.split('\n').indexed) {
        if (dong.contains('formatIncome') || dong.contains('formatExpense')) {
          viPham.add('$duongDan:${i + 1}  ${dong.trim()}');
        }
      }
    }

    expect(
      viPham,
      isEmpty,
      reason: 'Dùng `CurrencyFormatter.formatCoDau(soTien, thu: …)` thay cho '
          '`formatIncome`/`formatExpense`: hai hàm kia luôn gắn dấu, kể cả cho '
          'số 0, nên `+0 đ` / `-0 đ` lọt ra màn hình. Bẫy này đã tái phát BA '
          'lần và cả ba đều do máy ảo bắt, không phải bộ test.\n'
          'Chỗ còn lại:\n${viPham.join('\n')}',
    );
  });

  test('danh sách được phép không được phình ra trong im lặng', () {
    expect(
      _duocPhep.keys.toSet(),
      {'lib/core/utils/currency_formatter.dart'},
      reason: 'mỗi tệp thêm vào đây là một chỗ luật thôi được thi hành — phải '
          'là một quyết định có người đọc, không phải một dòng lặng lẽ',
    );
  });
}
