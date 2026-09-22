/// Test quét `lib/` thứ MƯỜI BỐN: `lib/features/ai_edge/` KHÔNG được tự tính.
///
/// ## Canh chừng điều gì
///
/// Mọi con số của tầng Edge phải đến từ hàm domain đã có (`budgetPaceOf`,
/// `thuNhapCua`, `tyLeTietKiem`, `phanTramSoVoi`, `duBaoCua`…). Một phép so
/// chiều tiền viết lại ở đây là **bản định nghĩa thứ hai** — và bản thứ hai là
/// thứ đã sinh ra bẫy A8 #8 (thu nhập gồm cả tiền đi vay, mục 3.24
/// `ANALYTICS_FEATURE.md`): tháng nào người dùng vay tiền, "thu nhập" vọt lên,
/// không exception nào báo.
///
/// ## Vì sao phải quét thay vì tin vào lượt viết
///
/// Lớp AI sẽ lớn dần ở P3 (prompt, cache, runtime). Một dòng `type == 'chi'`
/// chen vào lúc ấy để "tính nhanh một con số" trông vô hại và không test nào
/// của tính năng thấy — cho tới khi con số ấy lệch với thẻ bên cạnh. Test này
/// biến điều ấy thành lỗi ngay khi viết.
///
/// Dòng chú thích được bỏ qua: tài liệu trong mã có quyền nhắc tới khuôn bị cấm
/// để giải thích vì sao nó bị cấm.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const cam = [
    "'thu'",
    "'chi'",
    "'transfer'",
    'walletId',
    'transactionDao',
    'db.transactions',
    '.type ==',
    'amount <',
    'amount >',
  ];

  test('ai_edge/ không chứa phép so chiều tiền hay truy cập bảng giao dịch',
      () {
    final loi = <String>[];
    final goc = Directory('lib/features/ai_edge');
    expect(goc.existsSync(), isTrue, reason: 'thư mục ai_edge phải tồn tại');
    for (final f in goc.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        final d = dongs[i].trim();
        if (d.startsWith('//') || d.startsWith('///')) continue;
        for (final c in cam) {
          if (d.contains(c)) loi.add('${f.path}:${i + 1}: $c');
        }
      }
    }
    expect(
      loi,
      isEmpty,
      reason: 'Lớp AI chỉ được NHẬN số, không được tính. Chuyển phép tính về '
          'hàm domain của màn tương ứng rồi truyền kết quả vào gói số:\n'
          '${loi.join('\n')}',
    );
  });
}
