/// Dây nối DI của gia đình trong `injection_container.dart` — vùng mù của mọi test dựng đối tượng bằng tay: tham số tuỳ chọn
/// không được truyền thì không lỗi biên dịch, không đỏ ca nào, chỉ là tính năng im lặng không chạy.
///
/// - `nhaPhien:` của engine đồng bộ: thiếu là hàng Chủ nhà sửa hộ không bao giờ vào lô đẩy (spec 2026-11-01 mục 7.1).
/// - `dayTruocKhiRoi:` + `demHangChuaDay:` của repository nhà: thiếu là Rời nhà / Giải tán không đẩy, không đếm, và hàng chưa
///   đẩy mất sau khi server từ chối (mục 7.3).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Khối đăng ký bắt đầu từ [dau], tới dòng kế tiếp thụt lề đúng hai dấu cách mở bằng `sl.` hoặc chú thích.
String _khoi(String nguon, String dau) {
  final i = nguon.indexOf(dau);
  expect(i, isNonNegative, reason: 'không thấy chỗ đăng ký "$dau" trong injection_container.dart');
  final cuoi = nguon.indexOf(RegExp(r'\n  (sl\.|//)'), i + dau.length);
  expect(cuoi, greaterThan(i), reason: 'không tìm được cuối khối "$dau"');
  return nguon.substring(i, cuoi);
}

void main() {
  final nguon = File('lib/core/di/injection_container.dart').readAsStringSync().replaceAll('\r\n', '\n');

  test('đăng ký engine đồng bộ truyền nhaPhien (nhà đang ở)', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<SyncEngine>(');
    expect(khoi, contains('nhaPhien:'), reason: 'thiếu thì lô đẩy chỉ có hàng của tôi — hàng sửa hộ nằm pending mãi');
  });

  test('phép dọn tài khoản khác tính lại số dư ví nhà khi chưa biết nhà', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<PhienDieuPhoi>(');
    final i = khoi.indexOf('donTaiKhoanKhac:');
    expect(i, isNonNegative);
    final thanHam = khoi.substring(i, khoi.indexOf('xoaCacheSlm:'));
    expect(thanHam, contains('tinhLaiViNha()'),
        reason: 'thiếu thì ví nhà bị giữ mà sổ bị cắt: kéo toàn bộ đặt neo từ số dư cũ, tiền cộng hai lần và bị đẩy cho cả nhà');
    expect(thanHam, contains('donVaTinhLaiViNha('),
        reason: 'phải qua hàm bọc catch (core/auth/don_tai_khoan_khac.dart): lỗi tính lại ném thẳng là khoá cửa đăng nhập');
    expect(thanHam, contains('nhaGiu: nhaGiu'), reason: 'chỉ tính lại khi chưa biết nhà; đã biết nhà thì sổ của nhà giữ nguyên');
  });

  test('đăng ký repository nhà truyền dayTruocKhiRoi và demHangChuaDay', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<NhaRepository>(');
    expect(khoi, contains('dayTruocKhiRoi:'), reason: 'thiếu thì Rời nhà / Giải tán không đẩy trước khi gọi API');
    expect(khoi, contains('demHangChuaDay:'), reason: 'thiếu thì không biết còn hàng chưa đẩy để hỏi lại');
    expect(khoi, contains('dayVaCho('), reason: 'phải là lối đẩy-và-CHỜ, không phải lối xin đẩy rồi trả về ngay');
    expect(khoi, contains('demHangChuaDayCuaNha('));
  });

  test('đăng ký GopQuyService truyền đủ giaoDich, soDuVi và henDongBo', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<GopQuyService>(');
    expect(khoi, contains('giaoDich: sl<TransactionRepository>()'), reason: 'phải qua repository giao dịch: neo số dư trước khi ghi cặp');
    expect(khoi, contains('soDuVi:'), reason: 'thiếu thì sửa / xoá cặp không tính lại số dư hai ví');
    expect(khoi, contains('henDongBo:'), reason: 'thiếu thì sửa / xoá cặp nằm pending không ai xin đồng bộ');
  });
}
