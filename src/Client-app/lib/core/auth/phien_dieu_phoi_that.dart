/// Bản thi hành [PhienDieuPhoi]: bốn dịch vụ của `core` qua constructor, mọi việc thuộc mảng khác qua HOOK hàm — nên
/// `core/auth` không import `features/`; việc nối hook nằm ở `injection_container.dart`. Dịch vụ / hook `null` = hôm nay
/// `sl.isRegistered` trả false → bỏ qua, giữ đúng hành vi cũ (kể cả: không có SyncEngine thì không dọn, không quét).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../api/interceptors/auth_interceptor.dart';
import '../notification/notification_scanner.dart';
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
    required Future<int> Function(int idaccount) xoaBanSao,
    Future<void> Function()? xoaCacheSlm,
    Future<void> Function(int idaccount)? chuyenHangSeedCu,
    Future<int> Function(int idaccount)? taoBanSaoDanhMuc,
    Future<void> Function(int idaccount)? seedTaiKhoanMoi,
    Future<void> Function()? xoaAnhQuet,
    void Function()? datLaiCoGiaoDien,
    Future<void> Function(int idaccount)? datGoi,
  })  : _dongBo = dongBo, _thoiGianThuc = thoiGianThuc, _boQuet = boQuet,
        _donTaiKhoanKhac = donTaiKhoanKhac, _xoaBanSao = xoaBanSao, _xoaCacheSlm = xoaCacheSlm,
        _chuyenHangSeedCu = chuyenHangSeedCu, _taoBanSaoDanhMuc = taoBanSaoDanhMuc,
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
  final Future<int> Function(int) _xoaBanSao;
  final Future<void> Function()? _xoaCacheSlm;
  final Future<void> Function(int)? _chuyenHangSeedCu;
  final Future<int> Function(int)? _taoBanSaoDanhMuc;
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
    if (cho) {
      await e.start(idaccount: idaccount);
      if (e.hasCompletedPull) await _taoBanSao(idaccount);
      return;
    }
    // Đường mở app: không đợi một vòng mạng; bản sao nối vào sau. Pull hỏng thì bỏ qua, lần mở app sau thử lại.
    unawaited(e.start(idaccount: idaccount).then((_) async {
      if (!e.hasCompletedPull) return;
      await _taoBanSao(idaccount);
    }));
  }

  Future<void> _taoBanSao(int idaccount) async {
    final daTao = await _taoBanSaoDanhMuc?.call(idaccount) ?? 0;
    if (daTao > 0) {
      debugPrint('[Category] Đã tạo $daTao bản sao danh mục mặc định.');
      _dongBo?.scheduleSync(); // hàng vừa tạo nằm sau chu kỳ vừa xong — phải hẹn đẩy (AuthBloc cũ, 2026-09-07)
    }
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
  Future<void> xoaDuLieu(int idaccount) => _xoaBanSao(idaccount);

  @override
  Future<void> dispose() async {
    for (final s in _subs) { await s.cancel(); }
    await _phienChet.close();
    await _buoc.close();
  }
}
