/// Bản thi hành [PhienDieuPhoi]: ba dịch vụ của `core` (SyncEngine · RealtimeChannel · AuthInterceptor) và bộ quét thông báo qua constructor, mọi việc thuộc mảng khác qua HOOK hàm — nên
/// `core/auth` chỉ biết mảng Thông báo qua `NotificationScanner` (bộ quét — điểm ghép thứ tư — quét 25; bộ quét về `features/notification/application` 2026-10-15); mọi hook khác nối ở `injection_container.dart`. Dịch vụ / hook `null` = hôm nay
/// `sl.isRegistered` trả false → bỏ qua, giữ đúng hành vi cũ (kể cả: không có SyncEngine thì không dọn, không quét).
library;

import 'dart:async';

import '../api/interceptors/auth_interceptor.dart';
import '../../features/notification/application/notification_scanner.dart';
import '../realtime/realtime_channel.dart';
import '../sync/sync_engine.dart';
import 'buoc_dang_xuat.dart';
import 'phien_dieu_phoi.dart';

class PhienDieuPhoiThat implements PhienDieuPhoi {
  PhienDieuPhoiThat({
    required SyncEngine? dongBo,
    required RealtimeChannel? thoiGianThuc,
    required NotificationScanner? boQuet,
    required AuthInterceptor? interceptor,
    required Future<int> Function(int idaccount) donTaiKhoanKhac,
    Future<void> Function()? xoaCacheSlm,
    Future<void> Function(int idaccount)? chuyenHangSeedCu,
    Future<void> Function(int idaccount)? seedTaiKhoanMoi,
    Future<void> Function()? xoaAnhQuet,
    void Function()? datLaiCoGiaoDien,
    Future<void> Function(int idaccount)? datGoi,
  })  : _dongBo = dongBo, _thoiGianThuc = thoiGianThuc, _boQuet = boQuet,
        _donTaiKhoanKhac = donTaiKhoanKhac, _xoaCacheSlm = xoaCacheSlm,
        _chuyenHangSeedCu = chuyenHangSeedCu,
        _seedTaiKhoanMoi = seedTaiKhoanMoi, _xoaAnhQuet = xoaAnhQuet, _datLaiCoGiaoDien = datLaiCoGiaoDien,
        _datGoi = datGoi {
    final chet = dongBo?.sessionInvalidStream;
    if (chet != null) _subs.add(chet.listen(_phienChet.add));
    final hetHan = interceptor?.sessionExpiredStream;
    if (hetHan != null) _subs.add(hetHan.listen(_phienChet.add));
    final socket = thoiGianThuc?.buocDangXuat;
    if (socket != null) _subs.add(socket.listen(_buoc.add));
    final http = interceptor?.taiKhoanBiTuChoi;
    if (http != null) _subs.add(http.listen(_buoc.add));
  }

  final SyncEngine? _dongBo;
  final RealtimeChannel? _thoiGianThuc;
  final NotificationScanner? _boQuet;
  final Future<int> Function(int) _donTaiKhoanKhac;
  final Future<void> Function()? _xoaCacheSlm;
  final Future<void> Function(int)? _chuyenHangSeedCu;
  final Future<void> Function(int)? _seedTaiKhoanMoi;
  final Future<void> Function()? _xoaAnhQuet;
  final Future<void> Function(int)? _datGoi;
  final void Function()? _datLaiCoGiaoDien;

  final _phienChet = StreamController<void>.broadcast();
  final _buoc = StreamController<ThongBaoBuocDangXuat>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  Stream<void> get phienCoTheChet => _phienChet.stream;
  @override
  Stream<ThongBaoBuocDangXuat> get buocDangXuat => _buoc.stream;

  @override
  Future<void> moPhienCucBo(int idaccount) async {
    if (_dongBo == null) return; // khối `if (sl.isRegistered<SyncEngine>())` cũ
    final daDon = await _donTaiKhoanKhac(idaccount);
    // Cache SLM chỉ xoá khi máy vừa đổi người dùng — đăng nhập lại cùng tài khoản thì giữ (AuthBloc cũ).
    if (daDon > 0) await _xoaCacheSlm?.call();
    await _chuyenHangSeedCu?.call(idaccount);
    // G93: gói (kho đã lưu) phải có tài khoản TRƯỚC lượt quét đầu — pha này chạy trước `AuthSuccess`, còn gói chỉ nghe
    // phiên qua `AuthSuccess`; thiếu bước này thì cửa quyền của bộ chạy nền trả `true` và Basic bị tự trả / tự trích.
    await _datGoi?.call(idaccount);
    await _boQuet?.start(idaccount);
  }

  @override
  Future<void> batThoiGianThuc(int idaccount) async {
    if (_dongBo == null) return;
    await _thoiGianThuc?.start(idaccount: idaccount);
  }

  @override
  Future<void> batDongBo(int idaccount, {required bool cho}) async {
    final e = _dongBo;
    if (e == null) return;
    // Bản sao danh mục mặc định KHÔNG tạo ở đây (từ 2026-10-20): bộ gieo chạy trong chu kỳ đồng bộ, sau mỗi lượt kéo về
    // thành công (cổng `SyncEngine.sauKeoVe`, quy tắc 8). `start()` đợi chu kỳ đầu, nên đường đăng nhập vẫn có bản sao
    // trước `AuthSuccess` khi lượt kéo ấy thành công.
    if (cho) {
      await e.start(idaccount: idaccount);
      return;
    }
    // Đường mở app: không đợi một vòng mạng.
    unawaited(e.start(idaccount: idaccount));
  }

  @override
  Future<void> sauDangNhap(int idaccount) async {
    if (_dongBo != null) await _seedTaiKhoanMoi?.call(idaccount);
    _datLaiCoGiaoDien?.call();
  }

  @override
  Future<void> dongPhien() async {
    _dongBo?.stop();
    await _boQuet?.stop();
    await _thoiGianThuc?.stop();
    await _xoaAnhQuet?.call();
  }


  @override
  Future<void> dispose() async {
    for (final s in _subs) { await s.cancel(); }
    await _phienChet.close();
    await _buoc.close();
  }
}
