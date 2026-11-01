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
    expect(thanHam, contains('traVeKhiBoNha: (idNha, idaccount) => sl<GopQuyConflictResolver>().traVeKhiBoNha('),
        reason: 'thiếu thì phép dọn xoá nửa nhà cũ chưa đẩy mà không hoàn tiền về ví riêng (M-1)');
    expect(thanHam, contains('cacNhaConTrenMay: () => sl<AppDatabase>().cacNhaConTrenMay()'));
    expect(thanHam, contains('idaccount: id'));
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

  test('đăng ký GopQuyConflictResolver truyền taiKhoanPhien lấy từ phiên, không giá trị mặc định', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<GopQuyConflictResolver>(');
    expect(khoi, contains('taiKhoanPhien: () => sl<GoiRepository>().idaccount'),
        reason: 'thiếu thì không biết nửa nào là của mình (gỡ nhầm nửa của người khác); null (lượt nền chưa đặt tài khoản) = không gỡ');
    expect(khoi, contains('xinKeoLai: (id) => sl<SyncEngine>().keoLaiToanBo(id)'),
        reason: 'thiếu thì hàng sửa / xoá hộ bị ROLE_FORBIDDEN được gỡ nhưng không có lượt kéo toàn bộ trả bản server (I-2)');
    for (final tham in ['db:', 'gopQuy:', 'nha:', 'soDuVi:', 'henDongBo:']) {
      expect(khoi, contains(tham), reason: 'thiếu $tham thì resolver dựng sai / gỡ xong không xin đồng bộ');
    }
  });

  test('noiBoNgheKetQuaDay nghe GopQuyConflictResolver đúng một lần, SAU Bill resolver', () {
    final i = nguon.indexOf('void noiBoNgheKetQuaDay()');
    expect(i, isNonNegative);
    final than = nguon.substring(i);
    const dau = 'sl<GopQuyConflictResolver>().batDauNghe(';
    expect(RegExp(RegExp.escape(dau)).allMatches(nguon).length, 1,
        reason: 'nghe hai lần là gỡ chạy hai lượt cho cùng một thất bại; toàn tệp chỉ một lời gọi (như quét 5 với Bill)');
    expect(than.indexOf(dau), greaterThan(than.indexOf('sl<BillPaymentConflictResolver>().batDauNghe(')),
        reason: 'đặt SAU Bill resolver; hàm này chạy ở cả main.dart lẫn chay_nen.dart nên một chỗ là đủ');
  });

  test('cổng sauKeoVe gọi xuLyNuaNhaBiXoa trong try và trả lại số của viecSauKeoVeDanhMuc', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<SyncEngine>(');
    final i = khoi.indexOf('sauKeoVe:');
    final thanHam = khoi.substring(i, khoi.indexOf('trangThaiMayChu:'));
    expect(thanHam, contains('xuLyNuaNhaBiXoa(id)'), reason: 'thiếu thì Chủ nhà xoá nửa nhà, nửa riêng ở lại mồ côi mãi');
    expect(thanHam, contains('try {'), reason: 'lỗi gỡ không được làm hỏng lượt kéo về');
    expect(thanHam, contains('return soBanSao'), reason: 'ViecSauKeoVe trả số bản sao của việc danh mục — nuốt số là đổi nghĩa lượt kéo');
  });

  test('DieuPhoiDoiNha nhận truocKhiDon (trả tiền trước khi dọn) và main.dart truyền daDocNha', () {
    final khoi = _khoi(nguon, 'sl.registerLazySingleton<DieuPhoiDoiNha>(');
    expect(khoi, contains('truocKhiDon:'), reason: 'thiếu thì rời nhà xoá hàng chưa đẩy mà tiền không về ví riêng');
    expect(khoi, contains('traVeKhiBoNha('));
    expect(khoi, contains('taiKhoanPhien:'), reason: 'thiếu thì sự kiện NhaDaDoc cũ dọn nhầm hàng của tài khoản đang đăng nhập');
    final main = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    expect(main, contains('daDocNha: sl<NhaRepository>().daDocNha'),
        reason: 'thiếu thì hàng nhà kẹt (không có cặp DoiNha) không bao giờ được dọn');
  });
}
