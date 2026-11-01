/// Đọc `app_router.dart` như tài liệu (khuôn `*_noi_day_test`; điều hướng là vùng mù của widget test đơn lẻ): form Thêm giao
/// dịch có HAI cửa — `/add` của cá nhân và `/nha/khoan` của nhà — và phạm vi nhà không được lọt sang cửa cá nhân.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final nguon = File('lib/core/router/app_router.dart').readAsStringSync();

  /// Thân một `GoRoute(path: '<duong>'` tới `GoRoute` gốc kế tiếp (route con `routes:` nằm trong thân).
  String than(String duong) {
    final i = nguon.indexOf("path: '$duong'");
    expect(i, greaterThan(-1), reason: 'router phải có route $duong');
    final j = nguon.indexOf(RegExp(r"\n\s*GoRoute\(\s*\n?\s*path: '/"), i + 10);
    return nguon.substring(i, j == -1 ? nguon.length : j);
  }

  test('/add KHÔNG mang nha: và nguon: — nút + thanh dưới không vào được phạm vi nhà', () {
    final add = than('/add');
    expect(add.contains('nha:'), isFalse, reason: 'nha: ở /add là mở chế độ nhà từ cửa cá nhân');
    expect(add.contains('nguon:'), isFalse, reason: 'nguon: ở /add là ghi khoản cá nhân vào ví nhà');
  });

  test('/nha/khoan có nha:, nguon: và gọi huongFormNha', () {
    final nha = than('/nha/khoan');
    expect(nha.contains('nha: CheDoNhaForm('), isTrue);
    expect(nha.contains('nguon: sl<ThemGiaoDichNguonNha>('), isTrue);
    expect(nha.contains('huongFormNha('), isTrue,
        reason: 'ruling I-4: Thành viên mở ?huong=transfer phải về Chi tiêu, không vào đoạn Chuyển khoản');
  });

  test('route cha VÀ route con đều qua MỘT cửa quyền ghiKhoan (chờ kho trước khi đọc vai)', () {
    final nha = than('/nha/khoan');
    expect('_veNhaNeuKhongGhiDuoc()'.allMatches(nha).length, 2,
        reason: 'cả /nha/khoan lẫn /nha/khoan/category phải có redirect — thiếu một là deeplink vào thẳng bộ chọn');
    final i = nguon.indexOf('Future<String?> _veNhaNeuKhongGhiDuoc()');
    expect(i, greaterThan(-1));
    final cua = nguon.substring(i, nguon.indexOf('class AppRouter', i));
    expect(cua.contains('choNapKho()'), isTrue, reason: 'khuôn G92: chờ kho trước khi đọc vai');
    expect(cua.contains('ViecNha.ghiKhoan'), isTrue);
  });

  test('/nha/khoan/category dùng napCay của nhà và ẩn nút quản lý (T11 mới bật)', () {
    final nha = than('/nha/khoan');
    expect(nha.contains('napCayDanhMuc('), isTrue);
    expect(nha.contains('duongQuanLy: null'), isTrue);
  });
}
