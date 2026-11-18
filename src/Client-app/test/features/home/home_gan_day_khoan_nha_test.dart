/// "Giao dịch gần đây" ở Trang chủ hiện khoản của NHÀ do tôi ghi, còn thu chi tháng thì KHÔNG (spec 2026-11-16 mục 3).
///
/// Quét nguồn (khuôn `trang_chu_gon_test.dart`): dựng `HomePage` thật đòi nửa cái app. Logic bên dưới có test riêng —
/// truy vấn `transaction_kem_nha_test.dart`, nhãn nhà `transaction_row_content_test.dart`, tổng `transaction_filter_test.dart`.
/// Ở đây canh NỐI DÂY: hai nguồn khác nhau cho hai việc khác nhau.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final nguon = File('lib/features/home/presentation/pages/home_page.dart').readAsStringSync();

  test('danh sách gần đây đọc watchAllKemNha; thu chi tháng vẫn đọc watchAll (chỉ riêng)', () {
    expect(nguon.contains('sl<TransactionRepository>().watchAllKemNha(currentUserId)'), isTrue,
        reason: 'không có thì khoản ghi vào ví chung từ nút + biến mất khỏi Trang chủ');
    final i = nguon.indexOf('final txStream = (currentUserId != null)');
    expect(i, greaterThan(-1));
    expect(nguon.substring(i, i + 120).contains('.watchAll(currentUserId)'), isTrue,
        reason: 'thu chi tháng mà đọc bản kèm nhà là đếm một đồng tiền hai lần (góp quỹ đã là khoản chi riêng)');
    expect(nguon.contains('thuChiThangCua(transactions, now)'), isTrue);
  });

  test('bảng tra gộp ví / danh mục của nhà và tên nhà; dòng vẽ viên nhãn nhà', () {
    expect(nguon.contains('sl<KhoanNhaChoSoNguon>().traTen(currentUserId)'), isTrue);
    expect(nguon.contains('tenNha: nha.tenTheoId'), isTrue);
    expect(nguon.contains('DongPhuGiaoDich('), isTrue);
    expect(nguon.contains('tenNha: content.nhanNha'), isTrue);
  });
}
