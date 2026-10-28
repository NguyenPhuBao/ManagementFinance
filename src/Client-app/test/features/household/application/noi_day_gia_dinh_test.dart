/// Nối dây của gia đình — vùng `flutter test` không dựng được (DI thật, `main.dart`), canh bằng đọc mã nguồn như
/// `noi_bo_nghe_hai_noi_test`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final di = File('lib/core/di/injection_container.dart').readAsStringSync().replaceAll('\r\n', '\n');
  final mainDart = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');

  test('phép dọn lúc đổi tài khoản giữ nhà theo KHO của tài khoản mới (spec 4.6 đường 1)', () {
    final i = di.indexOf('donTaiKhoanKhac:');
    expect(i, isNonNegative);
    final dong = di.substring(i, di.indexOf('\n      xoaCacheSlm:', i));
    expect(dong, contains('nhaGiu:'), reason: 'thiếu là mọi lần mở app xoá sạch dữ liệu của nhà');
    expect(dong, contains('NhaRepository>().nhaDaLuu('));
  });

  test('main.dart: bộ điều phối nghe TRƯỚC khi trạng thái nhà nối phiên; nối đúng một lần', () {
    final nghe = RegExp(r'DieuPhoiDoiNha>\(\)\s*\.batDauNghe\(').allMatches(mainDart).toList();
    expect(nghe, hasLength(1));
    final noiPhien =
        mainDart.indexOf('..noiPhien(authBloc.stream.where(laTrangThaiPhienRo).map(idaccountTuTrangThai))');
    expect(noiPhien, isNonNegative,
        reason:
            'trạng thái nhà phải nghe phiên từ ĐÚNG bloc của app, và CHỈ trạng thái phiên rõ: `idaccountTuTrangThai` trả '
            'null với AuthLoading / AuthInitial — không lọc là xoaPhien ở mọi trạng thái chuyển tiếp rồi datTaiKhoan lại '
            '(nhấp nháy "không nhà", thêm một lượt /me) — cùng cách main.dart:216 lọc cho khoá ứng dụng');
    expect(nghe.single.start, lessThan(noiPhien),
        reason: 'doiNha là broadcast — nối sau thì DoiNha của lượt làm mới đầu rơi mất (dữ liệu cũ của nhà không về)');
    // Đọc TRONG khối nối của NhaRepository: khối `GoiRepository` ngay trên cũng có `..noiVongDoi(…)` / `..noiSuKien(…)` y
    // hệt — kiểm cả tệp là ca xanh sẵn, không canh gì.
    final dauKhoi = mainDart.indexOf('sl<NhaRepository>()\n');
    expect(dauKhoi, isNonNegative, reason: 'mất khối nối `sl<NhaRepository>()..noiPhien(…)` ở main.dart');
    final khoi = mainDart.substring(dauKhoi, mainDart.indexOf(';', dauKhoi));
    expect(khoi, contains('..noiPhien(authBloc.stream.where(laTrangThaiPhienRo).map(idaccountTuTrangThai))'));
    expect(khoi, contains('..noiVongDoi(sl<AppLifecycleWatcher>().stream)'),
        reason: 'thiếu là trạng thái nhà không làm mới khi app quay lại (resumed giãn 5 phút)');
    expect(khoi, contains('..noiSuKien(sl<RealtimeChannel>().events)'),
        reason: 'thiếu là household.changed / household.invited không bao giờ tới NhaRepository');
  });
}
