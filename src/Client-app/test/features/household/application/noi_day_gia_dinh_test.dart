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
    expect(dong, matches(RegExp(r'\(id\) async (=>|\{)[\s\S]*nhaDaLuu\(id\)')),
        reason: 'nhaDaLuu phải đọc kho của CHÍNH tài khoản mới (id), không phải id khác: đọc nhầm thì nhaGiu luôn null và '
            'mỗi lần mở app xoá sạch dữ liệu nhà trong khi kho vẫn mang nhà (không DoiNha, lịch sử không về lại)');
  });

  test('G114: PhienDieuPhoiThat được nối hook xinKeoToanBo → SyncEngine.keoLaiToanBo', () {
    final i = di.indexOf('xinKeoToanBo:');
    expect(i, isNonNegative, reason: 'thiếu là hook không bao giờ chạy: sau phép dọn lượt kéo đầu hỏng làm mất dữ liệu');
    expect(di.substring(i, di.indexOf('\n', i)), contains('sl<SyncEngine>().keoLaiToanBo(id)'));
    expect(i, greaterThan(di.indexOf('donTaiKhoanKhac:')), reason: 'cùng lời dựng PhienDieuPhoiThat');
  });

  test('DI: bộ điều phối ghi dấu vào kho nhà', () {
    final i = di.indexOf('registerLazySingleton<DieuPhoiDoiNha>');
    expect(i, isNonNegative);
    expect(di.substring(i, di.indexOf('));', i)), contains('ghiDau: (id, nha) => sl<NhaStore>().ghiDauXuLy(id, nha)'),
        reason: 'thiếu là dấu không bao giờ dời, mỗi lần mở app đều kéo toàn bộ');
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

  test('main.dart: lời mời vừa về đánh thức bộ quét; DI ánh xạ lời mời cho bộ luật', () {
    expect(mainDart, contains('ma.difference(maLoiMoiDaBao).isNotEmpty'),
        reason: 'thiếu là thông báo lời mời chỉ hiện ở lượt quét sau đồng bộ kế tiếp');
    expect(mainDart, contains('quetKhiRanh(id)'), reason: '`scan` bỏ qua khi đang quét, mất lượt im lặng');
    expect(di, contains('loadLoiMoiNha: (id) => sl<NhaRepository>().idaccount != id'));
  });

  test('FINAL: CapGopQuyNguon chờ kho nhà nạp (choNapKho, khuôn G92) TRƯỚC khi đọc cặp', () {
    final i = di.indexOf('registerLazySingleton<CapGopQuyNguon>');
    expect(i, isNonNegative);
    final khoi = di.substring(i, di.indexOf('xoa: (maCap)', i));
    final cho = khoi.indexOf('choNapKho()');
    expect(cho, isNonNegative,
        reason: 'trong khe mở app `hienTai.nha == null`, cổng trả null và nửa riêng đi đường xoá MỘT nửa: lệch cặp');
    expect(cho, lessThan(khoi.indexOf('docCapGopQuy(')), reason: 'phải chờ TRƯỚC khi đọc, không sau');
  });

  test('router: /nha/tao qua cửa quyền giaDinh', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final i = router.indexOf("path: '/nha/tao'");
    expect(i, isNonNegative);
    expect(router.substring(i, router.indexOf('builder:', i)), contains('redirectTheoQuyen(MaQuyen.giaDinh)'),
        reason: 'thiếu là Basic vào được form, bị server trả 403 sau khi đã gõ xong');
  });
}
